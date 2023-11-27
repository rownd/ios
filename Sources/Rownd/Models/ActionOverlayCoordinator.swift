//
//  File.swift
//  
//
//  Created by Bobby Radford on 10/30/23.
//

import Foundation
import SwiftUI

internal typealias ActionOverlayAnchor = UIView

internal class ActionOverlayCoordinator : ActionOverlayControllerPresentationContextProviding, ActionOverlayControllerDelegate {
    
    private var parent: Rownd
    private var mobileAppTagger = MobileAppTagger()
    private var webSocketDelegate: RowndWebSocketDelegate = RowndWebSocket()
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
    }
    
    func connect(_ url: String) throws -> Void {
        try webSocketDelegate.connect(url)
    }
    
    func disconnect() -> Void {
        webSocketDelegate.disconnect()
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
            
    class Actions {
        private var parent: ActionOverlayCoordinator
        
        init(_ parent: ActionOverlayCoordinator) {
            self.parent = parent
        }
        
        func capturePage() -> Void {
            self.parent.setState(state: .capturingPage)
            Task {
                /// Get the recursiveDescription of the root view UIWindow
                let rootView = try await getUIWindow()
                guard let rootViewDescription = rootView?.value(forKey: "recursiveDescription") as? String else {
                    logger.error("Failed to capture page. root view recursiveDescription could not be determined")
                    return
                }
                let rootViewDescriptionBase64 = rootViewDescription.data(using: .utf8)?.base64EncodedString()
                
                /// Take a screenshot
                let screenshot = try await captureScreenshot()
                let screenshotDataBase64 = screenshot?.pngData()?.base64EncodedString()
                
                guard let rootViewDescriptionBase64 = rootViewDescriptionBase64 else {
                    logger.error("Failed to capture page. root view recursiveDescription could not be encoded")
                    return
                }
                
                guard let screenshotDataBase64 = screenshotDataBase64 else {
                    logger.error("Failed to capture page. Unable to take screenshot")
                    return
                }
                
                do {
                    var _ = try await self.parent.mobileAppTagger.capturePage(rootViewDescriptionBase64: rootViewDescriptionBase64, screenshotDataBase64: screenshotDataBase64)
                } catch {
                    logger.error("Failed to capture page \(error)")
                    self.parent.setState(state: .failure, withDelayNS: 2_000_000_000)
                    return
                }
                
                self.parent.setState(state: .success, withDelayNS: 2_000_000_000)
            }
        }
    }
    
    // MARK: - Static main thread UI helper functions

    internal static func getUIWindow() async throws -> UIWindow? {
        let task = Task { @MainActor () -> UIWindow? in
            let allScenes = UIApplication.shared.connectedScenes
            for scene in allScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows where window.isKeyWindow {
                   return window
                }
            }
            return nil
        }
        return try await task.result.get()
    }
    
    internal static func captureScreenshot() async throws -> UIImage? {
        let task = Task { @MainActor () -> UIImage? in
            let window = try await getUIWindow()
            UIGraphicsBeginImageContextWithOptions(window!.frame.size, window!.isOpaque, 0.0)
            window!.layer.render(in: UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image;
        }
        return try await task.result.get()
    }
}
