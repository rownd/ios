//
//  AppDelegate.swift
//  ios native
//
//  Created by Matt Hamann on 6/23/22.
//

import Foundation
import SwiftUI
import Rownd
import Lottie

class AppCustomizations : RowndCustomizations {
//    override var sheetBackgroundColor: UIColor {
//        return UIColor(red: 225/255, green: 225/255, blue: 225/255, alpha: 1.0)
//    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    
    var authRepo: AuthRepository?
    //    func extractTextFromViews(view: UIView) -> [String] {
//        var texts = [String]()
//        
//        // Check if the view is a UILabel
//        if let label = view as? UILabel {
//            if let text = label.text {
//                texts.append(text)
//            }
//        }
//        
//        // Check if the view is a SwiftUI Text view
//        if let textView = view as? UIHostingController<Text> {
//            if let text = textView.rootView {
//                texts.append(text)
//            }
//        }
//        
//        // Recursively check subviews
//        for subview in view.subviews {
//            texts.append(contentsOf: extractTextFromViews(view: subview))
//        }
//        
//        return texts
//    }
    
//    func findHostingControllers(in viewController: UIViewController) -> [UIHostingController<AnyView>] {
//        var hostingControllers = [UIHostingController<AnyView>]()
//        
//        if let hostingController = viewController as? UIHostingController<AnyView> {
//            hostingControllers.append(hostingController)
//        }
//        
//        for child in viewController.children {
//            hostingControllers.append(contentsOf: findHostingControllers(in: child))
//        }
//        
//        return hostingControllers
//    }
//    
//    func extractAccessibilityLabels(from view: UIView) -> [String] {
//        var labels = [String]()
//        
//        
//        
//        // Check if the view has an accessibilityLabel
//        let origValue = view.isAccessibilityElement
//        view.isAccessibilityElement = true
//        if let label = view.accessibilityLabel ?? view.accessibilityValue {
//            labels.append(label)
//        }
//        view.isAccessibilityElement = origValue
//        
//        // Recursively check subviews
//        for subview in view.subviews {
//            labels.append(contentsOf: extractAccessibilityLabels(from: subview))
//        }
//        
//        return labels
//    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
//        Rownd.config.forceDarkMode = true
        Rownd.config.baseUrl = "https://hub.dev.rownd.io"
//        Rownd.config.baseUrl = "https://fcd3-99-37-55-241.ngrok-free.app"
        Rownd.config.apiUrl = "https://api.us-east-2.dev.rownd.io"
//        Rownd.config.apiUrl = "https://rowndapi.mhamann.com"
//        Rownd.config.apiUrl = "https://api.us-east-2.dev.rownd.io"
//        Rownd.config.apiUrl = "https://d5e9-99-37-55-241.ngrok.io"
//        Rownd.config.baseUrl = "http://localhost:8787"
//        Rownd.config.apiUrl = "http://localhost:3124"
//        Rownd.config.apiUrl = "http://192.168.86.249:3124"
//        Rownd.config.baseUrl = "http://192.168.86.249:8787"
        Rownd.config.subdomainExtension = ".dev.rownd.link"

//
        Rownd.config.customizations = AppCustomizations()

//        Rownd.config.customizations.loadingAnimation = Animation.named("check-mark4", bundle: Bundle.main)!
        
        Task {
            await Rownd.configure(launchOptions: launchOptions, appKey: "key_pko8eul59xz33hr21jgxvx6s")
            let _ = try? await Rownd.getAccessToken()
        }
        
//        Rownd.subscribeTo { event, state in
//            print("Received state event: \(String(describing: event)), \(String(describing: state))")
//        }
        
//        Task {
//            let appWindow = UIApplication.shared.windows.first!
//            let allAccessibilityLabels = extractAccessibilityLabels(from: appWindow)
//            print("a11yLabels:: \(String(describing: allAccessibilityLabels))")
//        }
        
        authRepo = AuthRepository()
        
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

        // TODO: handle URL from here
        Rownd.handleSignInLink(url: url)

        return true
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool
    {
        // Get URL components from the incoming user activity.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL,
              let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
            return false
        }

        return Rownd.handleSignInLink(url: incomingURL)
    }

    func scene(_ scene: UIScene, willConnectTo
               session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        // Get URL components from the incoming user activity.
        guard let userActivity = connectionOptions.userActivities.first,
              userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL,
              let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
            return
        }

        Rownd.handleSignInLink(url: incomingURL)
    }
}
