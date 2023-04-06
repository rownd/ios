//
//  GoogleSignInCoordinator.swift
//  Rownd
//
//  Created by Matt Hamann on 4/4/23.
//

import Foundation
import GoogleSignIn
import UIKit

class GoogleSignInCoordinator: NSObject {
    var parent: Rownd
    var intent: RowndSignInIntent?
    
    init(_ parent: Rownd) {
        self.parent = parent
        super.init()
    }
    
    func signIn(_ intent: RowndSignInIntent?, completion: (() -> Void)? = nil) {
        let googleConfig = store.state.appConfig.config?.hub?.auth?.signInMethods?.google
        guard googleConfig?.enabled == true, let googleConfig = googleConfig else {
            return logger.error("Sign in with Google is not enabled. Turn it on in the Rownd platform")
        }
        
        if (googleConfig.serverClientId == nil ||
            googleConfig.serverClientId == "" ||
            googleConfig.iosClientId == nil ||
            googleConfig.iosClientId == "") {
            return logger.error("Cannot sign in with Google. Missing client configuration")
        }
        
        let reversedClientId = googleConfig.iosClientId!.split(separator: ".").reversed().joined(separator: ".")
        if let url = NSURL(string: reversedClientId + "://") {
            if (UIApplication.shared.canOpenURL(url as URL) == false) {
                return logger.error("Cannot sign in with Google. \(String(describing: reversedClientId)) is not defined in URL schemes")
            }
        }
        
        let gidConfig = GIDConfiguration(
            clientID: (googleConfig.iosClientId)!,   // (IOS)
            serverClientID: googleConfig.serverClientId  // (Web)
        )
        
        GIDSignIn.sharedInstance.signIn(
            with: gidConfig,
            presenting: parent.getRootViewController()!
        ) { user, error in
            guard error == nil else {
                Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                    loginStep: .Error
                ))
                return logger.error("Failed to sign in with Google: \(String(describing: error))")
            }
            guard let user = user else { return }
            
            user.authentication.do { authentication, error in
                guard error == nil else { return }
                guard let authentication = authentication else { return }
                
                if let idToken = authentication.idToken {
                    logger.debug("Successully completed Google sign-in")
                    Auth.fetchToken(idToken: idToken, intent: intent) { tokenResponse in
                        if (tokenResponse?.userType == UserType.NewUser && intent == RowndSignInIntent.signIn) {
                            Rownd.requestSignIn(
                                jsFnOptions: RowndSignInJsOptions(
                                    token: idToken,
                                    loginStep: .NoAccount,
                                    intent: .signIn
                                )
                            )
                        } else {
                            DispatchQueue.main.async {
                                store.dispatch(SetAuthState(
                                    payload: AuthState(
                                        accessToken: tokenResponse?.accessToken,
                                        refreshToken: tokenResponse?.refreshToken
                                    )
                                ))
                                store.dispatch(UserData.fetch())
                                store.dispatch(SetLastSignInMethod(payload: SignInMethodTypes.google))
                                
                                Rownd.requestSignIn(
                                    jsFnOptions: RowndSignInJsOptions(
                                        loginStep: .Success,
                                        intent: intent,
                                        userType: tokenResponse?.userType
                                    )
                                )
                            }
                        }
                    }
                    
                } else {
                    logger.error("Could not complete Google sign-in. Missing idToken")
                }
                
                if let completion = completion {
                    completion()
                }
            }
        }
    }
}
