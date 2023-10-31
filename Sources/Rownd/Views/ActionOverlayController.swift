//
//  File.swift
//  
//
//  Created by Bobby Radford on 10/26/23.
//

import Foundation
import SwiftUI

protocol MobileTagger {
    func capturePage(rootViewDescriptionBase64: String, screenshotDataBase64: String) async throws -> CreatePageResponse?
}


// Empty for now
protocol ActionOverlayControllerDelegate {}

public class ActionOverlayController: UIViewController, URLSessionWebSocketDelegate {
    let fab = FAB()
    private var webSocket : URLSessionWebSocketTask?
    private var timer: Timer?
    private var rowndWebSocket: RowndWebSocket?
    
    var presentationContextProvider: ActionOverlayControllerPresentationContextProviding?
    var delegate: ActionOverlayControllerDelegate?
    
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

        self.view.addSubview(fab)
        fab.addTarget(self, action: #selector(capturePage), for: .touchUpInside)
        
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
    
    @objc func capturePage(_ sender: UIButton) {
        Rownd.capturePage()
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
