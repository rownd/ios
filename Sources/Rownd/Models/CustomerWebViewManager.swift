//
//  CustomerWebViewManager.swift
//
//
//  Created by Bobby Radford on 4/8/25.
//

import Foundation
import WebKit

typealias WKScriptMessageHandlerProvider = (_ customerWebViewId: String) -> WKScriptMessageHandler

internal class CustomerWebViewManager {
    var webViews: [ManagedWebView] = []
    var wkScriptMessageHandlerProvider: WKScriptMessageHandlerProvider
    
    convenience init() {
        self.init(wkScriptMessageHandlerProvider: nil)
    }
    
    init(wkScriptMessageHandlerProvider: WKScriptMessageHandlerProvider?) {
        if let provider = wkScriptMessageHandlerProvider {
           self.wkScriptMessageHandlerProvider = provider
        } else {
            self.wkScriptMessageHandlerProvider = { customerWebViewId in
                return CustomerWebViewMessageHandler(customerWebViewId: customerWebViewId)
            }
        }
    }
    
    func register(_ webView: WKWebView) -> (() -> Void) {
        let id = UUID().uuidString

        let userScript = """
            var _rphConfig = (window._rphConfig = window._rphConfig || []);
            _rphConfig.push(['setDisplayContext', 'web_view']);
        """

        webView.configuration.userContentController.add(self.wkScriptMessageHandlerProvider(id), name: "rowndIosSDK")
        webView.configuration.userContentController.addUserScript(WKUserScript(source: userScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        
        let managedWebView = ManagedWebView(id: id, webView: webView)

        webViews.append(managedWebView)
        
        // Return a closure that can be called to deregister a web view
        return { [weak self, id] in
            guard let self = self else { return }
            if let index = self.webViews.firstIndex(where: { $0.id == id }) {
                let webView = self.webViews[index].webView
                logger.debug("Deregistering web view \(id)")
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "rowndIosSDK")
                self.webViews.remove(at: index)
                logger.trace("Web view \(id) successfully deregistered")
            } else {
                logger.warning("Attempted to deregister web view \(id), but it wasn't found")
            }
        }
    }

    func webView(id: String) -> WKWebView? {
        return webViews.first(where: { $0.id == id })?.webView
    }
    
    func evaluateJavaScript(webViewId: String, code: String) {
        guard let webView = self.webView(id: webViewId) else {
            return
        }

        let wrappedJs = """
            if (typeof rownd !== 'undefined') {
                \(code)
            } else {
                _rphConfig.push(['onLoaded', () => {
                    \(code)
                }]);
            }
        """

        logger.trace("[Managed WebView (\(webViewId))] Evaluating script: \(Redact.redactSensitiveKeys(in: code))")

        webView.evaluateJavaScript(wrappedJs) { (result, error) in
            if error == nil {
                logger.trace("[Managed WebView (\(webViewId))]JavaScript evaluation finished with result: \(String(describing: result))")
            } else {
                logger.error("[Managed WebView (\(webViewId))] Evaluation of '\(code)' failed: \(String(describing: error))")
            }
        }
    }
}

struct ManagedWebView {
    var id: String
    var webView: WKWebView
}
