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
    func capturePage(viewHierarchyStringBase64: String, screenshotDataBase64: String) async throws -> CreatePageResponse?
}

protocol ActionOverlayControllerPresentationContextProviding {
    func presentationAnchor(for controller: ActionOverlayController) async throws -> ActionOverlayAnchor
}

// Empty for now
protocol ActionOverlayControllerDelegate {}

class ActionOverlayController: UIViewController, URLSessionWebSocketDelegate, UIGestureRecognizerDelegate {
    private var webSocket : URLSessionWebSocketTask?
    private var timer: Timer?
    private var rowndWebSocket: RowndWebSocket?

    var presentationContextProvider: ActionOverlayControllerPresentationContextProviding?
    var delegate: ActionOverlayControllerDelegate?
    
    private var trailingAnchorConstraint: NSLayoutConstraint!
    private var bottomAnchorConstraint: NSLayoutConstraint!
    
    var viewModel: ActionOverlayViewModelProto? {
        didSet {
            self.fillUI()
        }
    }
    
    func fillUI() {
        Task { @MainActor in
            guard let viewModel = viewModel else {
                return
            }

            self.fab.alpha = viewModel.fabAlpha
            self.fab.backgroundColor = viewModel.fabBackgroundColor
            
            self.fab.setImage(viewModel.fabImage, for: .normal)
            self.fab.imageEdgeInsets = viewModel.fabImageInsets
            
            self.fab.addTarget(viewModel.fabTarget, action: viewModel.fabAction, for: viewModel.fabTargetControlEvents)
            
            if self.trailingAnchorConstraint != nil {
                self.trailingAnchorConstraint.constant = viewModel.fabPosition.x
            } else {
                self.trailingAnchorConstraint = self.fab.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: viewModel.fabPosition.x)
            }

            if self.bottomAnchorConstraint != nil {
                self.bottomAnchorConstraint.constant = viewModel.fabPosition.y
            } else {
                self.bottomAnchorConstraint = self.fab.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: viewModel.fabPosition.y)
            }
                
            NSLayoutConstraint.activate([
                self.fab.heightAnchor.constraint(equalToConstant: 56),
                self.fab.widthAnchor.constraint(equalToConstant: 56),
                self.trailingAnchorConstraint,
                self.bottomAnchorConstraint
            ])
        }
    }
    
    private var fab = {
        let button = UIButton(type: .custom)

        button.layer.cornerRadius = 28 // half the height and width
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.isUserInteractionEnabled = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentMode = .scaleAspectFit
        
        return button
    }()
    
    func show() -> Void {
        guard let presentationContextProvider = presentationContextProvider else {
            logger.error("presentationContextProvider unset for ActionOverlayController")
            return
        }
    
        Task { @MainActor in
            do {
                let anchor = try await presentationContextProvider.presentationAnchor(for: self)
                anchor.addSubview(self.view)
                anchor.bringSubviewToFront(self.view)
            } catch {
                logger.error("Failed to show action overlay. Erorr in presentation context provider: \(String(describing: error))")
            }
        }
    }
    
    func hide() -> Void {
        fab.removeFromSuperview()
    }
        
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.fillUI()

        self.view.addSubview(fab)
                        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(fabLongPressed))
        longPressGesture.delegate = self
        self.fab.addGestureRecognizer(longPressGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(fabDragged))
        panGesture.delegate = self
        self.fab.addGestureRecognizer(panGesture)
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        webSocket?.cancel(with: .goingAway, reason: nil)
    }
    
    @objc func fabLongPressed(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            // Handle long-press action here
            print("Button long-pressed!")
        }
    }

    @objc func fabDragged(sender: UIPanGestureRecognizer) {
        guard let viewModel = self.viewModel else {
            return
        }

        let translation = sender.translation(in: self.view)
        let newX = viewModel.fabPosition.x + translation.x
        let newY = viewModel.fabPosition.y + translation.y

        if sender.state == .changed {
            self.viewModel?.fabPosition.x = newX > -16 ? -16 : newX
            self.viewModel?.fabPosition.y = newY > -16 ? -16 : newY
            sender.setTranslation(.zero, in: self.view)
        }
        
//        print("newX \(newX), newY \(newY)")
    }
}
