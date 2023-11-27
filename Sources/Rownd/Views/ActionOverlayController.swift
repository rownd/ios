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
    func presentationAnchor(for controller: ActionOverlayController) async throws -> ActionOverlayAnchor
}

// Empty for now
protocol ActionOverlayControllerDelegate {}


extension UIView {
    var trailingConstraint: NSLayoutConstraint? {
        get {
            return constraints.first(where: {
                $0.firstAttribute == .trailing && $0.relation == .equal
            })
        }
        set { setNeedsLayout() }
    }

    var bottomConstraint: NSLayoutConstraint? {
        get {
            return constraints.first(where: {
                $0.firstAttribute == .bottom && $0.relation == .equal
            })
        }
        set { setNeedsLayout() }
    }
}

class ActionOverlayController: UIViewController, URLSessionWebSocketDelegate, UIGestureRecognizerDelegate {
    private var webSocket : URLSessionWebSocketTask?
    private var timer: Timer?
    private var rowndWebSocket: RowndWebSocket?

    var presentationContextProvider: ActionOverlayControllerPresentationContextProviding?
    var delegate: ActionOverlayControllerDelegate?
    
//    private var trailingConstraint: NSLayoutConstraint!
//    private var bottomConstraint: NSLayoutConstraint!
    
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
            self.fab.addTarget(viewModel.fabTarget, action: viewModel.fabAction, for: viewModel.fabTargetControlEvents)
            
            //        self.trailingConstraint = self.fab.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: viewModel.fabPosition.x)
            //        self.bottomConstraint = self.fab.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: viewModel.fabPosition.y)
            
            //        NSLayoutConstraint.activate([
            //            fab.heightAnchor.constraint(equalToConstant: 56),
            //            fab.widthAnchor.constraint(equalToConstant: 56),
            ////            self.trailingConstraint,
            ////            self.bottomConstraint,
            //            fab.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            //            fab.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
            //        ])
        }
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
        
        fab.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            fab.heightAnchor.constraint(equalToConstant: 56),
            fab.widthAnchor.constraint(equalToConstant: 56),
//            self.trailingConstraint,
//            self.bottomConstraint,
//            fab.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: viewModel.fabPosition.x),
//            fab.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: viewModel.fabPosition.y)
            fab.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            fab.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
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
        let translation = sender.translation(in: self.view)

        if sender.state == .changed {
            self.fab.trailingConstraint?.constant += translation.x
            self.fab.bottomConstraint?.constant += translation.y
//            self.viewModel?.fabPosition.x += translation.x
//            self.viewModel?.fabPosition.y += translation.y
//            self.trailingConstraint.constant += translation.x
//            self.bottomConstraint.constant += translation.y
            sender.setTranslation(.zero, in: self.view)
        }
    }
}
