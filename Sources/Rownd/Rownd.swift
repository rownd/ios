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
import WebKit
import AnyCodable

public class Rownd: NSObject {
    private static let inst: Rownd = Rownd()
    public static var config: RowndConfig = RowndConfig.inst
    public static let user = UserPropAccess()
    
    private override init() {}
    
    public static func configure(launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil, appKey: String?) async {
        if let _appKey = appKey {
            config.appKey = _appKey
        }
        
        inst.inflateStoreCache()
        inst.loadAppConfig()
        
        if await Rownd.getAccessToken() != nil {
            store.dispatch(SetUserLoading(isLoading: false)) // Make sure user is not in loading state during initial bootstrap
            store.dispatch(UserData.fetch())
        }
        
        var launchUrl: URL?
        if let _launchUrl = launchOptions?[.url] as? URL {
            launchUrl = _launchUrl
        } else if UIPasteboard.general.hasURLs, let _launchUrl = UIPasteboard.general.url {
            launchUrl = _launchUrl
        }
        
        if (launchUrl?.host?.hasSuffix("rownd.link")) != nil {
            logger.trace("launch_url: \(String(describing: launchUrl?.absoluteString))")
            
            // TODO: Ask Rownd to handle this link (probably signing the user in)
        }
    }
    
    public static func getInstance() -> Rownd {
        return inst
    }
    
    public static func requestSignIn() {
        let _ = inst.displayHub(.signIn)
    }
    
    public static func signOut() {
        let _ = inst.displayHub(.signOut)
        store.dispatch(SetAuthState(payload: AuthState()))
    }
    
    public static func getAccessToken() async -> String? {
        return await store.state.auth.getAccessToken()
    }
    
    public func state() -> Store<RowndState> {
        return store
    }
    
//    public func state(type: RowndStateType) -> StateObject<AnyObject> {
//        switch(type) {
//        case .auth:
//            return state().subscribe { $0.auth }
//        case .none
//            return nil
//        }
//    }
    
    // MARK: Internal methods
    private func loadAppConfig() {
        store.dispatch(AppConfig().fetch())
    }
    
    private func inflateStoreCache() {
        RowndState.load()
    }
    
    private func displayHub(_ page: HubPageSelector) -> HubViewController {
        let rootViewController = UIApplication.shared.connectedScenes
                .filter({$0.activationState == .foregroundActive})
                .compactMap({$0 as? UIWindowScene})
                .first?.windows
                .filter({$0.isKeyWindow}).first?.rootViewController
        
        let hubController = HubViewController()
        hubController.targetPage = page
        
        rootViewController?.present(hubController, animated: true)
        
        return hubController
    }
    
}

public class UserPropAccess {
    public func get() -> UserState {
        return store.state.user
    }
    
    public func get(field: String) -> Any {
        return store.state.user.data[field] ?? nil
    }
    
    public func get<T>(field: String) throws -> T? {
        guard let value = store.state.user.data[field] else {
            return nil
        }
        
        return value as? T
    }
    
    public func set(data: Dictionary<String, AnyCodable>) -> Void {
        store.dispatch(UserData.save(data))
    }
    
    public func set(field: String, value: AnyCodable) -> Void {
        var userData = store.state.user.data
        userData[field] = value
        store.dispatch(UserData.save(userData))
    }
}

public enum RowndStateType {
    case auth, user, app, none
}

public enum UserFieldAccessType {
    case string, int, float, dictionary, array
}
