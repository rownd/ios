//
//  SceneManager.swift
//  ios native
//
//  Created by Matt Hamann on 5/23/23.
//

import SwiftUI
import Rownd

@main
struct LandmarksApp: App {
    @UIApplicationDelegateAdaptor var delegate: AppDelegate
    
    @StateObject var authState = Rownd.getInstance().state().subscribe { $0.auth }

    var body: some Scene {
        WindowGroup {            
            if authState.current.isAuthenticated {
                ContentView()
            } else {
                SplashView()
            }
        }
    }
}
