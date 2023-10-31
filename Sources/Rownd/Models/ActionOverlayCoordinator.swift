//
//  File.swift
//  
//
//  Created by Bobby Radford on 10/30/23.
//

import Foundation
import SwiftUI

internal typealias ActionOverlayAnchor = UIView

protocol ActionOverlayControllerPresentationContextProviding {
    func presentationAnchor(for controller: ActionOverlayController) -> ActionOverlayAnchor
}

internal class ActionOverlayCoordinator : ActionOverlayControllerPresentationContextProviding, ActionOverlayControllerDelegate {
    
    private var parent: Rownd
    private var actionOverlayController: ActionOverlayController = ActionOverlayController()
    private var webSocketDelegate: RowndWebSocketDelegate
    
    init(parent: Rownd, webSocket: RowndWebSocketDelegate) {
        self.parent = parent
        self.webSocketDelegate = webSocket
    }
   
    func show() -> Void {
        actionOverlayController.presentationContextProvider = self
        actionOverlayController.delegate = self
        actionOverlayController.show()
    }
    
    func hide() -> Void {
        actionOverlayController.hide()
    }
        
    func presentationAnchor(for controller: ActionOverlayController) -> ActionOverlayAnchor {
        let anchor = parent.getRootViewController()?.view
        guard let anchor = anchor else {
            logger.error("Unable to determine root view controller while attempting to display the action overlay")
            return parent.bottomSheetController.view
        }
        return anchor
    }
}
