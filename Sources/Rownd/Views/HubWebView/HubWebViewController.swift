//
//  WebViewController.swift
//  ios native
//
//  Created by Matt Hamann on 6/14/22.
//

import Foundation
import UIKit
import WebKit
import SwiftUI
import OSLog

let logger = Logger(subsystem: "io.rownd.sdk", category: "HubView")

public enum HubPageSelector {
    case signIn
    case signOut
    case unknown
}

public class HubWebViewController: UIViewController, WKUIDelegate {
    
    var webView: WKWebView!
    var url = URL(string: "https://hub.rownd.io/mobile_app")!
    var hubViewController: HubViewProtocol?
    var jsFunctionArgsAsJson: String = "{}"
    
    func setUrl(url: URL) {
        self.url = url
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        if let presentation = sheetPresentationController {
//            presentation.detents = [.medium(), .large()]
//            presentation.prefersGrabberVisible = true
//        }
    }
    
    public override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        
        // Receive messages from Hub JS
        let userController = WKUserContentController()
        userController.add(self, name: "rowndIosSDK")
        webConfiguration.userContentController = userController
        
        // Request mobile view
        let pref = WKWebpagePreferences.init()
        pref.preferredContentMode = .mobile
        webConfiguration.defaultWebpagePreferences = pref
        
        // Init WebView
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.customUserAgent = DEFAULT_WEB_USER_AGENT
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .systemGray6
        self.modalPresentationStyle = .pageSheet
        view = webView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let hubRequest = URLRequest(url: url)
        webView.load(hubRequest)
    }
}

extension HubWebViewController: WKScriptMessageHandler, WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
//        hubViewController?.setLoading(true)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //This function is called when the webview finishes navigating to the webpage.
        //We use this to send data to the webview when it's loaded.
        
        hubViewController?.setLoading(false)
        
        switch (hubViewController?.targetPage) {
        case .signOut:
            webView.evaluateJavaScript("rownd.signOut()") { (result, error) in
                if error != nil {
                    logger.error("Failed to request sign out from Rownd: \(String(describing: error))")
                }
            }
            
        case .signIn, .unknown:
            webView.evaluateJavaScript("rownd.requestSignIn(\(jsFunctionArgsAsJson))") { (result, error) in
                if error != nil {
                    logger.error("Failed to request sign in from Rownd: \(String(describing: error))")
                }
            }
        case .none:
            return
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        hubViewController?.setLoading(false)
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        //This function handles the events coming from javascript. We'll configure the javascript side of this later.
        //We can access properties through the message body, like this:
        guard let response = message.body as? String else { return }
        
        logger.trace("Received message from hub: \(response)")
        
        do {
            let hubMessage = try RowndHubInteropMessage.fromJson(message: response)
            
            logger.debug("Received message from hub with type: \(String(describing: hubMessage.type))")
            
            switch hubMessage.type {
            case .authentication:
                guard case .authentication(let authMessage) = hubMessage.payload else { return }
                if store.state.auth.isAuthenticated {
                    // The Hub is open for something else, so just chill...
                    return
                }
                store.dispatch(SetAuthState(payload: AuthState(accessToken: authMessage.accessToken, refreshToken: authMessage.refreshToken)))
                store.dispatch(UserData.fetch())
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in // Change `2.0` to the desired number of seconds.
                    self?.hubViewController?.hide()
                }
                
            case .triggerSignInWithApple:
                self.hubViewController?.hide()
                Rownd.requestAppleSignIn()
                
            case .signOut:
                store.dispatch(SetAuthState(payload: AuthState()))
                store.dispatch(SetUserData(payload: [:]))
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in // Change `2.0` to the desired number of seconds.
                    self?.hubViewController?.hide()
                }
            case .unknown:
                break
            }
        } catch {
            logger.error("Failed to decode incoming interop message: \(String(describing: error))")
        }
    }
}
