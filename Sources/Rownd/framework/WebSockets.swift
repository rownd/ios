//
//  File.swift
//  
//
//  Created by Bobby Radford on 10/31/23.
//

import Foundation
import AnyCodable

enum WebSocketError: Error {
    case invalidUrl, readOnDisconnectedSocket
}

protocol RowndWebSocketMessageHandlerDelegate {
    func handleMessage(_ result: Result<URLSessionWebSocketTask.Message, any Error>) -> Bool
}

class RowndWebSocketMessageHandler: RowndWebSocketMessageHandlerDelegate {
    func handleMessage(_ result: Result<URLSessionWebSocketTask.Message, any Error>) -> Bool {
        var shouldReceiveNext = false
        switch result {
        case .failure(let error):
            logger.debug("Failed to receive message: \(error)")
        case .success(let message):
            switch message {
            case .string(let text):
                logger.debug("Received text message: \(text)")
                shouldReceiveNext = handleStringMessage(text)
            case .data(let data):
                logger.debug("Received binary message: \(data)")
            @unknown default:
                fatalError()
            }
            
            shouldReceiveNext = true
        }
        
        return shouldReceiveNext
    }
    
    private func handleStringMessage(_ string: String) -> Bool {
        var shouldReceiveNext = true
        do {
            let message = try WebSocketMessage.fromJson(message: string)
            switch (message.messageType) {
            case .setActionOverlayState:
                let payload = try PayloadSetActionOverlayState.fromJson(message: message.payload)
                guard let state = ActionOverlayState(rawValue: payload.state) else {
                    logger.error("Web socket message included unsupported action overlay state: \(message.payload)")
                    break
                }
                Rownd.actionOverlay.setState(state: state)
            case .connected:
                break
            case .close:
                Rownd.actionOverlay.disconnect()
                shouldReceiveNext = false
                break
            case .captureScreen:
                Rownd.actionOverlay.setState(state: .captureScreen)
            case .captureScreenForPage:
                let payload = try PayloadCaptureScreenForPage.fromJson(message: message.payload)
                Rownd.actionOverlay.setCaptureForPageId(payload.pageId)
                Rownd.actionOverlay.setState(state: .captureScreen)
            default:
                logger.error("Unsupported web socket message \(string)")
                break
            }
        } catch {
            logger.error("Unable to parse web socket message \(string)")
        }
        return shouldReceiveNext
    }
}

protocol RowndWebSocketSessionDelegate {
    func session(ws: RowndWebSocket, didOpenWithProtocol protocol: String?) -> Void
    func session(ws: RowndWebSocket, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) -> Void
}

class RowndWebSocket : NSObject, URLSessionWebSocketDelegate {
    private lazy var session: URLSession = {
        return URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }()
    private var webSocket: URLSessionWebSocketTask?
    private var timer: Timer?
    private var messageHandler: RowndWebSocketMessageHandlerDelegate = RowndWebSocketMessageHandler()
    private var sessionDelegate: RowndWebSocketSessionDelegate?
    var connected: Bool {
        get {
            return webSocket?.state == .running
        }
    }
    
    init(sessionDelegate: RowndWebSocketSessionDelegate?) {
        self.sessionDelegate = sessionDelegate
    }
    
    func connect(_ url: String) throws -> Void {
        guard let _url = URL(string: url) else {
            throw WebSocketError.invalidUrl
        }
        
        let _webSocket = self.session.webSocketTask(with: _url)
        _webSocket.resume()

        self.webSocket = _webSocket
        
        try readMessage()
//        keepAlive()
    }
    
    func disconnect() -> Void {
        webSocket?.cancel(with: .goingAway, reason: nil)
        cancelKeepAlive()
        webSocket = nil
    }
    
    func sendMessage(_ msgType: WebSocketMessageMessage, payload: Encodable) async -> Void {
        logger.debug("Sending websocket message: \(String(describing: msgType)), payload: \(String(describing: payload))")

        do {
            let payloadString = try payload.asJsonString()
            let msg = WebSocketMessage(messageType: msgType, payload: payloadString)
            let taskMessage = try URLSessionWebSocketTask.Message.string(msg.asJsonString())
            try await webSocket?.send(taskMessage)
            return
        } catch {
            logger.error("Failed to send message to web socket: \(String(describing: error))")
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate impl
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol proto: String?) {
        logger.debug("Connected to websocket server")
        
        
        Task {
            await sendMessage(WebSocketMessageMessage.connected, payload: PayloadConnected(platform: "ios"))
        }
        
        self.sessionDelegate?.session(ws: self, didOpenWithProtocol: proto)
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.debug("Disconnect from websocket Server \(String(describing: reason))")
        self.sessionDelegate?.session(ws: self, didCloseWith: closeCode, reason: reason)
    }
        
    private func keepAlive() {
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.ping), userInfo: nil, repeats: true)
    }
    
    private func cancelKeepAlive() {
        if let timer = timer {
            timer.invalidate()
        }
    }
    
    private func readMessage() throws {
        guard let _webSocket = self.webSocket else {
            throw WebSocketError.readOnDisconnectedSocket
        }
        
        _webSocket.receive { result in
            let shouldReceiveNext = self.messageHandler.handleMessage(result)
            if shouldReceiveNext {
                do {
                    try self.readMessage()
                } catch {
                    logger.error("Failure in web socket message receive: \(String(describing: error))")
                }
            }
        }
    }
    
    @objc private func ping() {
        guard let webSocket = webSocket else {
            logger.error("ping called before websocket initialized")
            return
        }

        webSocket.sendPing { (error) in
            if let error = error {
                logger.error("Ping failed: \(error)")
            }
        }
    }
}

internal enum WebSocketMessageMessage: String, Codable {
    case getConnectionId = "get_connection_id"
    case connected = "connected"
    case captureScreenSucceeded = "capture_screen_succeeded"
    case captureScreenFailed = "capture_screen_failed"
    case setActionOverlayState = "set_action_overlay_state"
    case captureScreen = "capture_screen"
    case captureScreenForPage = "capture_screen_for_page"
    case close = "close"
}

internal struct WebSocketMessage: Codable {
    var messageType: WebSocketMessageMessage
    var payload: String
    
    enum CodingKeys: String, CodingKey {
        case messageType = "message_type"
        case payload = "payload"
    }
}

// MARK: - web socket message payloads

internal struct PayloadSetActionOverlayState: Codable {
    var state: String
    enum CodingKeys: String, CodingKey {
        case state = "state"
    }
}

internal struct PayloadConnected: Codable {
    var platform: String
    enum CodingKeys: String, CodingKey {
        case platform = "platform"
    }
}

internal struct PayloadCaptureScreenSucceeded: Codable {
    var page: CreatePageResponse
    var pageCapture: CreatePageCaptureResponse
    enum CodingKeys: String, CodingKey {
        case page = "page"
        case pageCapture = "page_capture"
    }
}

internal struct PayloadCaptureScreen: Codable {}

internal struct PayloadCaptureScreenForPage: Codable {
    var pageId: String
    enum CodingKeys: String, CodingKey {
        case pageId = "page_id"
    }
}
