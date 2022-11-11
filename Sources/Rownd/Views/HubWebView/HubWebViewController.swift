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
    case qrCode
    case manageAccount
    case unknown
}

fileprivate final class InputAccessoryHackHelper: NSObject {
    @objc var inputAccessoryView: AnyObject? { return nil }
}

extension WKWebView {
    func hack_removeInputAccessory() {
        guard let target = scrollView.subviews.first(where: {
            String(describing: type(of: $0)).hasPrefix("WKContent")
        }), let superclass = target.superclass else {
            return
        }

        let noInputAccessoryViewClassName = "\(superclass)_NoInputAccessoryView"
        var newClass: AnyClass? = NSClassFromString(noInputAccessoryViewClassName)

        if newClass == nil, let targetClass = object_getClass(target), let classNameCString = noInputAccessoryViewClassName.cString(using: .ascii) {
            newClass = objc_allocateClassPair(targetClass, classNameCString, 0)

            if let newClass = newClass {
                objc_registerClassPair(newClass)
            }
        }

        guard let noInputAccessoryClass = newClass, let originalMethod = class_getInstanceMethod(InputAccessoryHackHelper.self, #selector(getter: InputAccessoryHackHelper.inputAccessoryView)) else {
            return
        }
        class_addMethod(noInputAccessoryClass.self, #selector(getter: InputAccessoryHackHelper.inputAccessoryView), method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        object_setClass(target, noInputAccessoryClass)
    }
}

public class HubWebViewController: UIViewController, WKUIDelegate {
    
    var webView: WKWebView!
    var url: URL? = nil
    var hubViewController: HubViewProtocol?
    var jsFunctionArgsAsJson: String = "{}"
    
    func setUrl(url: URL) {
        self.url = url
        self.startLoading()
    }

    private func startLoading() {
        guard let webView = self.webView, let url = self.url else { return }

        // Skip loading if already begun
        if webView.isLoading { return }

        var hubRequest = URLRequest(url: url)
        hubRequest.timeoutInterval = 10
        webView.load(hubRequest)
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
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        webView.hack_removeInputAccessory()
        self.modalPresentationStyle = .pageSheet
        view = webView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        startLoading()
    }
}

extension HubWebViewController: WKScriptMessageHandler, WKNavigationDelegate {

    private func evaluateJavaScript(code: String, webView: WKWebView) {
        
        let wrappedJs = """
            if (typeof rownd !== 'undefined') {
                \(code)
            } else {
                _rphConfig.push(['onLoaded', () => {
                    \(code)
                }]);
            }
        """

        logger.trace("Evaluating script: \(code)")

        webView.evaluateJavaScript(wrappedJs) { (result, error) in
            logger.trace("JavaScript evaluation finished with result: \(String(describing: result))")
            if error != nil {
                logger.error("Evaluation of '\(code)' failed: \(String(describing: error))")
            }
        }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
//        hubViewController?.setLoading(true)
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        //This function is called whenever the Webview attempts to navigate to a different url
        if navigationAction.targetFrame == nil {
            let url = navigationAction.request.url
            if UIApplication.shared.canOpenURL(url!) {
                if (url?.absoluteString == "mailto:") {
                    //Opens inbox to default email
                    UIApplication.shared.open(URL(string: "message://")!, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.open(url!, options: [:], completionHandler: nil)
                }
            }
        }
        return nil
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //This function is called when the webview finishes navigating to the webpage.
        //We use this to send data to the webview when it's loaded.

        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        
        hubViewController?.setLoading(false)
        
        setFeatureFlagsJS()

        switch (hubViewController?.targetPage) {
        case .signOut:
            evaluateJavaScript(code: "rownd.signOut({\"show_success\":true})", webView: webView)
            
        case .signIn, .unknown:
            evaluateJavaScript(code: "rownd.requestSignIn(\(jsFunctionArgsAsJson))", webView: webView)
        case .qrCode:
            evaluateJavaScript(code: "rownd.generateQrCode(\(jsFunctionArgsAsJson))", webView: webView)
        case .manageAccount:
            evaluateJavaScript(code: "rownd.user.manageAccount()", webView: webView)
        case .none:
            return
        }
    }
    
    private func setFeatureFlagsJS() {
        let frameworkFeaturesString = String(describing: getFrameowrkFeatures())
        let code = """
            if (rownd?.setSessionStorage) {
                rownd.setSessionStorage("rph_feature_flags\",`\(frameworkFeaturesString)`)
            }
        """
        evaluateJavaScript(code: code, webView: webView)
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.loadHTMLString(NoInternetHTML(appConfig: store.state.appConfig), baseURL: nil)
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
                guard hubViewController?.targetPage == .signIn  else { return }
                DispatchQueue.main.async {
                    store.dispatch(store.state.auth.onReceiveAuthTokens(
                        AuthState(accessToken: authMessage.accessToken, refreshToken: authMessage.refreshToken)
                    ))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in // .now() + num_seconds
                    self?.hubViewController?.hide()
                }
            case .closeHubViewController:
                DispatchQueue.main.async {
                    self.hubViewController?.hide()
                }
            case .userDataUpdate:
                guard case .userDataUpdate(let userDataMessage) = hubMessage.payload else { return }
                guard hubViewController?.targetPage == .manageAccount else { return }
                DispatchQueue.main.async {
                    store.dispatch(SetUserData(payload: userDataMessage.data))
//                    store.dispatch(UserData.fetch())
                }
                
            case .triggerSignInWithApple:
                self.hubViewController?.hide()
                Rownd.requestSignIn(with: .appleId)
                
            case .triggerSignInWithGoogle:
                Rownd.requestSignIn(with: .googleId) {
                    self.hubViewController?.hide()
                }

            case .signOut:
                guard hubViewController?.targetPage == .signOut  else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in // .now() + num_seconds
                    self?.hubViewController?.hide()
                }
                DispatchQueue.main.async {
                    store.dispatch(SetAuthState(payload: AuthState()))
                    store.dispatch(SetUserData(payload: [:]))
                }
            case .tryAgain:
                startLoading()
            case .unknown:
                break
            }
        } catch {
            logger.error("Failed to decode incoming interop message: \(String(describing: error))")
        }
    }
}
