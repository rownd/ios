//
//  HubViewController.swift
//  framework
//
//  Created by Matt Hamann on 7/5/22.
//

import Foundation
import SwiftUI
import UIKit

protocol HubViewProtocol {
    var targetPage: HubPageSelector { get set }
    var hostController: UIViewController? { get set }

    func setLoading(_ isLoading: Bool)
    func show()
    func hide()
}

public class HubViewController: UIViewController, HubViewProtocol {
    
    var activityIndicator = UIActivityIndicatorView(style: .large)
    var hubWebController = HubWebViewController()
    var targetPage = HubPageSelector.unknown
    var hostController: UIViewController?
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        if let presentation = sheetPresentationController {
//            presentation.detents = [.medium(), .large()]
//            presentation.prefersGrabberVisible = true
//        }
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        
        hubWebController.didMove(toParent: self)
        hubWebController.view.frame = view.bounds
        hubWebController.view.autoresizingMask = .flexibleHeight
    }
    
    public override func loadView() {
        hubWebController.hubViewController = self
        
        let base64EncodedConfig = Rownd.config.toJson()
            .data(using: .utf8)?
            .base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)) ?? ""

        var hubLoaderUrl = URLComponents(string: "\(Rownd.config.baseUrl)/mobile_app?config=\(base64EncodedConfig)")

        // This ensures that the Hub in the webview doesn't attempt to refresh its own tokens,
        // which might trigger an undesired sign-out now or in the future
        if store.state.auth.isAuthenticated {
            let rphInit = store.state.auth.toRphInitHash()
            if let rphInit = rphInit {
                hubLoaderUrl?.fragment = "rph_init=\(rphInit)"
            }
        }
        
        hubWebController.setUrl(url: (hubLoaderUrl?.url)!)
        
        view = UIView()
        view.backgroundColor = .systemGray6
        addChild(hubWebController)
        view.addSubview(hubWebController.view)
        setupConstraints()
        
        if Rownd.config.forceDarkMode {
            self.overrideUserInterfaceStyle = .dark
        }

        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        guard let hostController = hostController else {
            return
        }

        hostController.dismiss(animated: true)
    }
    
    func setLoading(_ isLoading: Bool) {
        if (isLoading) {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
    
    func hide() {
        self.dismiss(animated: true)
    }
    
    func show() {
        view.isHidden = false
    }
    
    fileprivate func setupConstraints() {
        hubWebController.view.translatesAutoresizingMaskIntoConstraints = false
        hubWebController.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        hubWebController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        hubWebController.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        hubWebController.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
    
}
