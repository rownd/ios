//
//  File.swift
//  
//
//  Created by Bobby Radford on 10/31/23.
//

import Foundation

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
                handleStringMessage(text)
            case .data(let data):
                logger.debug("Received binary message: \(data)")
            @unknown default:
                fatalError()
            }
            
            shouldReceiveNext = true
        }
        
        return shouldReceiveNext
    }
    
    private func handleStringMessage(_ string: String) -> Void {
        do {
            let message = try WebSocketMessage.fromJson(message: string)
            switch (message.messageType) {
            case .setActionOverlayState:
                guard let state = ActionOverlayState(rawValue: message.payload) else {
                    logger.error("Web socket message included unsupported action overlay state: \(message.payload)")
                    return
                }
                Rownd.actionOverlay.setState(state: state)
            default:
                logger.error("Unsupported web socket message \(string)")
            }
        } catch {
            logger.error("Unable to parse web socket message \(string)")
        }
    }
}

protocol RowndWebSocketDelegate {
    func connect(_ url: String) throws -> Void
    func disconnect() -> Void
    func sendMessage(_ msg: WebSocketMessage) async -> Void
    var connected: Bool { get }
}

class RowndWebSocket : NSObject, RowndWebSocketDelegate, URLSessionWebSocketDelegate {
    private lazy var session: URLSession = {
        return URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }()
    private var webSocket: URLSessionWebSocketTask?
    private var timer: Timer?
    private var messageHandler: RowndWebSocketMessageHandlerDelegate = RowndWebSocketMessageHandler()
    var connected: Bool {
        get {
            return webSocket?.state == .running
        }
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
    
    func sendMessage(_ msg: WebSocketMessage) async -> Void {
        do {
            let taskMessage = try URLSessionWebSocketTask.Message.string(msg.asJsonString())
            try await webSocket?.send(taskMessage)
            return
        } catch {
            logger.error("Failed to send message to web socket: \(String(describing: error))")
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate impl
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.debug("Connected to websocket server")
        
        Task {
            await sendMessage(WebSocketMessage(messageType: WebSocketMessageMessage.connected, payload: "ios"))
        }
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.debug("Disconnect from websocket Server \(String(describing: reason))")
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
    case capturePageSucceeded = "capture_page_succeeded"
    case capturePageFailed = "capture_page_failed"
    case setActionOverlayState = "set_action_overlay_state"
}

internal struct WebSocketMessage: Encodable, Decodable {
    var messageType: WebSocketMessageMessage
    var payload: String
    
    enum CodingKeys: String, CodingKey {
        case messageType = "message_type"
        case payload = "payload"
    }
}
