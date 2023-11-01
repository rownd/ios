//
//  File.swift
//  
//
//  Created by Bobby Radford on 10/26/23.
//

import Foundation
import ReSwift
import SwiftUI

// MARK: Coordinator

protocol MobileTagger {
    func capturePage(rootViewDescriptionBase64: String, screenshotDataBase64: String) async throws -> CreatePageResponse?
}

protocol ActionOverlayControllerPresentationContextProviding {
    func presentationAnchor(for controller: ActionOverlayController) -> ActionOverlayAnchor
}

// Empty for now
protocol ActionOverlayControllerDelegate {}

class ActionOverlayController: UIViewController, URLSessionWebSocketDelegate {
    private var webSocket : URLSessionWebSocketTask?
    private var timer: Timer?
    private var rowndWebSocket: RowndWebSocket?

    var presentationContextProvider: ActionOverlayControllerPresentationContextProviding?
    var delegate: ActionOverlayControllerDelegate?
    
    var viewModel: ActionOverlayViewModelProto? {
        didSet {
            self.fillUI()
        }
    }
    
    func fillUI() {
        guard let viewModel = viewModel else {
            return
        }
        
        self.fab.setImage(viewModel.fabImage, for: .normal)
        self.fab.addTarget(viewModel.fabTarget, action: viewModel.fabAction, for: viewModel.fabTargetControlEvents)
    }
    
    private var fab = {
        let button = UIButton(type: .custom)

        button.backgroundColor = .white
        button.tintColor = UIColor(red: 90/255, green: 19/255, blue: 223/255, alpha: 1)
        button.layer.cornerRadius = 28 // half the height and width
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.isUserInteractionEnabled = true

        return button
    }()
    
    func show() -> Void {
        guard let presentationContextProvider = presentationContextProvider else {
            logger.error("presentationContextProvider unset for ActionOverlayController")
            return
        }
    
        let anchor = presentationContextProvider.presentationAnchor(for: self)
        anchor.addSubview(self.view)
        anchor.bringSubviewToFront(self.view)
    }
    
    func hide() -> Void {
        fab.removeFromSuperview()
    }
        
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.fillUI()

        self.view.addSubview(fab)
        
        NSLayoutConstraint.activate([
            fab.heightAnchor.constraint(equalToConstant: 56),
            fab.widthAnchor.constraint(equalToConstant: 56),
            fab.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            fab.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        fab.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        webSocket?.cancel(with: .goingAway, reason: nil)
    }
}

func FAB() -> UIButton {
    let button = UIButton(type: .custom)

    button.backgroundColor = .white
    button.tintColor = UIColor(red: 90/255, green: 19/255, blue: 223/255, alpha: 1)
    button.setImage(UIImage(systemName: "camera"), for: .normal)
    button.layer.cornerRadius = 28 // half the height and width
    button.layer.shadowColor = UIColor.black.cgColor
    button.layer.shadowOpacity = 0.25
    button.layer.shadowOffset = CGSize(width: 0, height: 2)
    button.layer.shadowRadius = 4
    button.isUserInteractionEnabled = true

    return button
}
