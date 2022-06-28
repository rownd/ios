//
//  WebSheetView.swift
//  ios native
//
//  Created by Matt Hamann on 6/13/22.
//

import Foundation
import SwiftUI
import WebKit

public enum RowndHubPage {
    case signIn
    case signOut
}

public struct RowndHubView: UIViewControllerRepresentable {
    public typealias UIViewControllerType = RowndHubViewController
    var currentPage: RowndHubPage?
    
    public init(page: RowndHubPage) {
        self.currentPage = page
    }
    
    public func makeUIViewController(context: Context) -> RowndHubViewController {
        let base64EncodedConfig = RowndConfig.inst.toJson()
            .data(using: .utf8)?
            .base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)) ?? ""

        let hubLoaderUrl = URL(string: "\(RowndConfig.inst.baseUrl)/mobile_app?config=\(base64EncodedConfig)")
        
        let webView = RowndHubViewController()
        
        webView.setUrl(url: hubLoaderUrl!)

        return webView
    }
    
    public func updateUIViewController(_ uiViewController: RowndHubViewController, context: Context) {
        
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
