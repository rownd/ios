//
//  WebSheetView.swift
//  ios native
//
//  Created by Matt Hamann on 6/13/22.
//

import Foundation
import SwiftUI
import WebKit

public struct HubWebView: UIViewControllerRepresentable {
    public typealias UIViewControllerType = HubWebViewController
    var currentPage: HubPageSelector?
    
    public init(page: HubPageSelector) {
        self.currentPage = page
    }
    
    public func makeUIViewController(context: Context) -> HubWebViewController {
        let base64EncodedConfig = RowndConfig.inst.toJson()
            .data(using: .utf8)?
            .base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)) ?? ""

        let hubLoaderUrl = URL(string: "\(RowndConfig.inst.baseUrl)/mobile_app?config=\(base64EncodedConfig)")
        
        let webView = HubWebViewController()
        
        webView.setUrl(url: hubLoaderUrl!)

        return webView
    }
    
    public func updateUIViewController(_ uiViewController: HubWebViewController, context: Context) {
        
    }
}
 
//struct WebView: UIViewRepresentable {
//
//    var url: URL
//
//    func makeUIView(context: Context) -> WKWebView {
//        return WKWebView()
//    }
//
//    func updateUIView(_ webView: WKWebView, context: Context) {
//        let request = URLRequest(url: url)
//        webView.load(request)
//    }
//}
