//
//  CustomerWebViewManager.swift
//
//
//  Created by Bobby Radford on 4/8/25.
//

import Foundation
import WebKit

class CustomerWebViewManager {
    var managedWebViews: [ManagedWebView] = []
    
    func register(_ webView: WKWebView) {
        let id = UUID().uuidString

        let userScript = """
            var _rphConfig = (window._rphConfig = window._rphConfig || []);
            _rphConfig.push(['setDisplayContext', 'web_view']);
        """

        webView.configuration.userContentController.add(CustomerWebViewMessageHandler(customerWebViewId: id), name: "rowndIosSDK")
        webView.configuration.userContentController.addUserScript(WKUserScript(source: userScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        
        let managedWebView = ManagedWebView(id: id, webView: webView)

        managedWebViews.append(managedWebView)
    }
    
    func webView(id: String) -> WKWebView? {
        return managedWebViews.first(where: { $0.id == id })?.webView
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

        logger.trace("[Managed WebView (\(webViewId)] Evaluating script: \(code)")

        webView.evaluateJavaScript(wrappedJs) { (result, error) in
            if error == nil {
                logger.trace("[Managed WebView (\(webViewId)] JavaScript evaluation finished with result: \(String(describing: result))")
            } else {
                logger.error("[Managed WebView (\(webViewId)] Evaluation of '\(code)' failed: \(String(describing: error))")
            }
        }
    }
}

struct ManagedWebView {
    var id: String
    var webView: WKWebView
}
