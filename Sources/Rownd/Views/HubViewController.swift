//
//  HubViewController.swift
//  framework
//
//  Created by Matt Hamann on 7/5/22.
//

import Foundation
import SwiftUI
import UIKit
import Lottie

protocol HubViewProtocol {
    var targetPage: HubPageSelector { get set }

    func setLoading(_ isLoading: Bool)
    func show()
    func hide()
    func height(_ height: CGFloat)
}

public class HubViewController: UIViewController, HubViewProtocol, BottomSheetHostProtocol {
    @objc var preferredHeightInBottomSheet: CGFloat = 550
    var activityIndicator = UIActivityIndicatorView(style: .large)
    var customLoadingAnimationView: Lottie.AnimationView?
    var hubWebController = HubWebViewController()
    var targetPage = HubPageSelector.unknown
    var hostController: BottomSheetController?
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        if let presentation = sheetPresentationController {
//            presentation.detents = [.medium(), .large()]
//            presentation.prefersGrabberVisible = true
//        }

        if let customLoadingAnimationView = customLoadingAnimationView {
            NSLayoutConstraint.activate([
                customLoadingAnimationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                customLoadingAnimationView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        }
        
        hubWebController.didMove(toParent: self)
        hubWebController.view.frame = view.bounds
        hubWebController.view.autoresizingMask = .flexibleHeight
    }
    
    public func loadNewPage(targetPage: HubPageSelector, jsFnOptions: Encodable?) {
        DispatchQueue.main.async {
            self.targetPage = targetPage
            if let jsFnOptions = jsFnOptions {
                do {
                    self.hubWebController.jsFunctionArgsAsJson = try jsFnOptions.asJsonString()
                } catch {
                    logger.error("Failed to encode JS options to pass to function: \(String(describing: error))")
                }
            }
            
            if self.hubWebController.webView.url != nil {
                self.hubWebController.webViewOnLoad(webView: self.hubWebController.webView, targetPage: targetPage, jsFnOptions: jsFnOptions)
            }
        }
    }
    
    public override func loadView() {
        hubWebController.hubViewController = self
        
        let base64EncodedConfig = Rownd.config.toJson()
            .data(using: .utf8)?
            .base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)) ?? ""

        let hubLoaderUrl = URLComponents(string: "\(Rownd.config.baseUrl)/mobile_app?config=\(base64EncodedConfig)&sign_in=\(store.state.signIn.toSignInHash() ?? "")")

        view = UIView()
        view.backgroundColor = Rownd.config.customizations.sheetBackgroundColor

        // This ensures that the Hub in the webview doesn't attempt to refresh its own tokens,
        // which might trigger an undesired sign-out now or in the future
        if store.state.auth.isAuthenticated {
            Task { [hubLoaderUrl] in
                var hubLoaderUrl = hubLoaderUrl // Capture local copy of var to prevent compiler mutation issues
                let _ = try? await Rownd.getAccessToken()
                let rphInit = store.state.auth.toRphInitHash()
                if let rphInit = rphInit {
                    hubLoaderUrl?.fragment = "rph_init=\(rphInit)"
                }

                DispatchQueue.main.async { [weak self, hubLoaderUrl] in
                    guard let self = self else { return }
                    self.hubWebController.setUrl(url: (hubLoaderUrl?.url)!)
                }
            }
        } else {
            hubWebController.setUrl(url: (hubLoaderUrl?.url)!)
        }

        addChild(hubWebController)
        view.addSubview(hubWebController.view)
        setupConstraints()

        
        if Rownd.config.forceDarkMode {
            self.overrideUserInterfaceStyle = .dark
        }

        if let _ = Rownd.config.customizations.loadingAnimation {
            customLoadingAnimationView = Rownd.config.customizations.loadingAnimationView
            view.addSubview(customLoadingAnimationView!)
        } else {
            activityIndicator.hidesWhenStopped = true
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            activityIndicator.startAnimating()
            view.addSubview(activityIndicator)
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        guard let hostController = hostController else {
            return
        }

        hostController.dismiss(animated: true)
    }
    
    func setLoading(_ isLoading: Bool) {
        if customLoadingAnimationView != nil {
            if (isLoading) {
                customLoadingAnimationView?.startAnimating()
            } else {
                customLoadingAnimationView?.stopAnimating()
            }
        } else {
            if (isLoading) {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }

    }
    
    func hide() {
        self.dismiss(animated: true)
    }
    
    func show() {
        view.isHidden = false
    }
    
    func height(_ number: CGFloat) {
        hostController?.randy(number)
    }
    
    fileprivate func setupConstraints() {
        hubWebController.view.translatesAutoresizingMaskIntoConstraints = false
        hubWebController.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        hubWebController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        hubWebController.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        hubWebController.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
    
}
