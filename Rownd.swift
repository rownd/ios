//
//  Rownd.swift
//  framework
//
//  Created by Matt Hamann on 6/23/22.
//

import Foundation
import SwiftUI
import UIKit
import ReSwift

public class Rownd: NSObject {
    private static let inst: Rownd = Rownd()
    static var config: RowndConfig = RowndConfig.inst
    
    private override init() {}
    
    public static func configure(launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil, appKey: String?) {
        if let _appKey = appKey {
            config.appKey = _appKey
        }
        
        inst.inflateStoreCache()
        inst.loadAppConfig()
        
        var launchUrl: URL?
        if let _launchUrl = launchOptions?[.url] as? URL {
            launchUrl = _launchUrl
        } else if UIPasteboard.general.hasURLs, let _launchUrl = UIPasteboard.general.url {
            launchUrl = _launchUrl
        }
        
        if (launchUrl?.host?.hasSuffix("rownd.link")) != nil {
            // TODO: Ask Rownd to handle this link (probably signing the user in)
        }
    }
    
    public static func getInstance() -> Rownd {
        return inst
    }
    
    public static func requestSignIn() -> RowndHubView {
        return RowndHubView(page: RowndHubPage.signIn)
    }
    
    public func state() -> Store<RowndState> {
        return store
    }
    
    public func signOut() {
        store.dispatch(SetAuthState())
    }
    
    // MARK: Internal methods
    private func loadAppConfig() {
        store.dispatch(AppConfig().fetch())
    }
    
    private func inflateStoreCache() {
        RowndState.load()
    }
    
    
}
