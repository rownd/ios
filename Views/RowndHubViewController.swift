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

public class RowndHubViewController: UIViewController, WKUIDelegate {
    
    var webView: WKWebView!
    var activityIndicator: UIActivityIndicatorView!
    var url: URL!
    
    func setUrl(url: URL) {
        self.url = url
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let presentation = sheetPresentationController {
            presentation.detents = [.medium(), .large()]
            presentation.prefersGrabberVisible = true
        }
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
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        self.modalPresentationStyle = .pageSheet
        view = webView
        
        // Activity indicator
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = UIActivityIndicatorView.Style.medium

        view.addSubview(activityIndicator)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let myRequest = URLRequest(url: url!)
        webView.load(myRequest)
    }
    
    func showActivityIndicator(show: Bool) {
        if show {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
}

extension RowndHubViewController: WKScriptMessageHandler, WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        showActivityIndicator(show: true)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //This function is called when the webview finishes navigating to the webpage.
        //We use this to send data to the webview when it's loaded.
        
        showActivityIndicator(show: false)
        
        webView.evaluateJavaScript("rownd.requestSignIn()") { (result, error) in
            if error != nil {
                print(error)
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showActivityIndicator(show: false)
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        //This function handles the events coming from javascript. We'll configure the javascript side of this later.
        //We can access properties through the message body, like this:
        guard let response = message.body as? String else { return }
        
        do {
            let hubMessage = try RowndHubInteropMessage.fromJson(message: response)
            switch hubMessage.payload {
            case .authentication(let authMessage):
                store.dispatch(SetAuthState(payload: AuthState(accessToken: authMessage.accessToken, refreshToken: authMessage.refreshToken)))
            default:
                break
            }
        } catch {
            logger.error("Failed to decode incoming interop message:")
            print(error)
        }
    }
}
