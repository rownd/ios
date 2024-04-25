//
//  File.swift
//  
//
//  Created by Bobby Radford on 10/30/23.
//

import Foundation
import SwiftUI

internal typealias ActionOverlayAnchor = UIView

internal class ActionOverlayCoordinator : ActionOverlayControllerPresentationContextProviding, ActionOverlayControllerDelegate, RowndWebSocketSessionDelegate {
    
    private var parent: Rownd
    private var mobileAppTagger = MobileAppTagger()
    lazy private var webSocket: RowndWebSocket = { return RowndWebSocket(sessionDelegate: self) }()
    private var actionOverlayController: ActionOverlayController?
    lazy internal var actions = { return Actions(self) }()
        
    init(parent: Rownd) {
        self.parent = parent
    }
   
    func show() -> Void {
        actionOverlayController = ActionOverlayController()
        actionOverlayController?.presentationContextProvider = self
        actionOverlayController?.delegate = self
        actionOverlayController?.viewModel = ActionOverlayViewModel()
        Task { @MainActor in actionOverlayController?.show() }
    }
    
    func hide() -> Void {
        actionOverlayController?.hide()
        actionOverlayController = nil
    }
    
    func connect(_ url: String) throws -> Void {
        try webSocket.connect(url)
    }
    
    func disconnect() -> Void {
        webSocket.disconnect()
    }
    
    func sendMessage(_ msgType: WebSocketMessageMessage, payload: Encodable) async -> Void {
        await webSocket.sendMessage(msgType, payload: payload)
    }
    
    func presentationAnchor(for controller: ActionOverlayController) async throws -> ActionOverlayAnchor {
        var anchor = try await Task { @MainActor in
            return await parent.getRootViewController()?.view
        }.result.get()
        
        if let anchor = anchor {
            return anchor
        }
        
        anchor = await UIApplication.shared.windows.last?.rootViewController?.view
        
        guard let anchor = anchor else {
            logger.error("Unable to determine root view controller while attempting to display the action overlay")
            return await parent.bottomSheetController.view
        }
        
        return anchor
    }
    
    func setPlatformAccessToken(_ token: String) -> Void {
        self.mobileAppTagger.platformAccessToken = token
    }
    
    func setCaptureForPageId(_ pageId: String?) -> Void {
        actionOverlayController?.viewModel?.pageId = pageId
    }
    
    func setState(state: ActionOverlayState) -> Void {
        actionOverlayController?.viewModel?.state = state
    }
    
    func setState(state: ActionOverlayState, withDelayNS: UInt64) {
        setState(state: state)
        if [.success, .failure].contains(state) {
            Task {
                try? await Task.sleep(nanoseconds: withDelayNS)
                setState(state: .ready)
            }
        }
    }
    
    // MARK: - RowndWebSocketSessionDelegate methods

    func session(ws: RowndWebSocket, didOpenWithProtocol protocol: String?) {
        // Websocket connection successfully opened
        // TODO: Do something in the future?
    }

    func session(ws: RowndWebSocket, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        // Websocket connection closed. Hide the action overlay.
        Task { @MainActor in
            self.hide()
        }
    }
            
    class Actions {
        private var parent: ActionOverlayCoordinator
        
        init(_ parent: ActionOverlayCoordinator) {
            self.parent = parent
        }
        
        func captureScreen() -> Void {
            self.captureScreen(forPageId: nil)
        }
        
        func captureScreen(forPageId pageId: String?) -> Void {
            self.parent.setState(state: .capturingScreen)
            Task {
                guard let rowndTree = await RowndTreeSerialization.serializeTree() else {
                    logger.error("Failed to capture page. Tree serialiation failed")
                    return
                }
                
                /// Take a screenshot
                let screenshot = try await captureScreenshot()
                guard let screenshot = screenshot else {
                    logger.error("Failed to take screenshot")
                    return
                }
                let screenshotDataBase64 = screenshot.pngData()?.base64EncodedString()
                
                guard let screenshotDataBase64 = screenshotDataBase64 else {
                    logger.error("Failed to capture page. Unable to take screenshot")
                    self.parent.setState(state: .failure, withDelayNS: 2_000_000_000)
                    return
                }
                
                var createdPage: MobileAppPage? = nil
                if pageId == nil {
                    do {
                        createdPage = try await self.parent.mobileAppTagger.createPage(name: nil)
                    } catch {
                        logger.error("Failed to create page \(error)")
                        self.parent.setState(state: .failure, withDelayNS: 2_000_000_000)
                        return
                    }
                }
                
                guard let captureForPageId = pageId ?? createdPage?.id else {
                    logger.error("Failed to assign page after creation")
                    self.parent.setState(state: .failure, withDelayNS: 2_000_000_000)
                    return
                }
                
                do {
                    guard let pageCapture = try await self.parent.mobileAppTagger.createPageCapture(pageId: captureForPageId, screenStructure: rowndTree, screenshotDataBase64: screenshotDataBase64, screenshotHeight: Int(screenshot.size.height), screenshotWidth: Int(screenshot.size.width)) else {
                        logger.error("Failed to create page capture")
                        self.parent.setState(state: .failure, withDelayNS: 2_000_000_000)
                        return
                    }
                    
                    // Fetch the page to include in the success message sent to the Platform
                    // via the websocket connection
                    guard let page = await PagesData.fetch(appId: pageCapture.appId, pageId: pageCapture.pageId) else {
                        logger.error("Failed to fetch page after page capture")
                        self.parent.setState(state: .failure, withDelayNS: 2_000_000_000)
                        return
                    }
                    
                    // Send a success message
                    await Rownd.actionOverlay.sendMessage(.captureScreenSucceeded, payload: PayloadCaptureScreenSucceeded(
                            page: page, pageCapture: pageCapture
                        ))
                } catch {
                    logger.error("Failed to create page capture \(error)")
                    self.parent.setState(state: .failure, withDelayNS: 2_000_000_000)
                    return
                }
                
                self.parent.setState(state: .success, withDelayNS: 2_000_000_000)
            }
        }
    }
    
    // MARK: - Static main thread UI helper functions
    
    internal static func captureScreenshot() async throws -> UIImage? {
        let task = Task { @MainActor () -> UIImage? in
            let window = try await RowndDeviceUtils.mainWindow()
            UIGraphicsBeginImageContextWithOptions(window!.frame.size, window!.isOpaque, 0.0)
            window!.layer.render(in: UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image;
        }
        return try await task.result.get()
    }
}
