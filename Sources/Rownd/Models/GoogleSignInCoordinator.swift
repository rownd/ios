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
    
    func signIn(_ intent: RowndSignInIntent?) async {
        let googleConfig = store.state.appConfig.config?.hub?.auth?.signInMethods?.google
        guard googleConfig?.enabled == true, let googleConfig = googleConfig else {
            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                loginStep: .error,
                signInType: .google
            ))
            return logger.error("Sign in with Google is not enabled. Turn it on in the Rownd platform")
        }
        
        if (googleConfig.serverClientId == nil ||
            googleConfig.serverClientId == "" ||
            googleConfig.iosClientId == nil ||
            googleConfig.iosClientId == "") {
            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                loginStep: .error,
                signInType: .google
            ))
            return logger.error("Cannot sign in with Google. Missing client configuration")
        }
        
        let reversedClientId = googleConfig.iosClientId!.split(separator: ".").reversed().joined(separator: ".")
        if let url = NSURL(string: reversedClientId + "://") {
            if (await UIApplication.shared.canOpenURL(url as URL) == false) {
                Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                    loginStep: .error,
                    signInType: .google
                ))
                return logger.error("Cannot sign in with Google. \(String(describing: reversedClientId)) is not defined in URL schemes")
            }
        }
        
        let gidConfig = GIDConfiguration(
            clientID: (googleConfig.iosClientId)!,   // (IOS)
            serverClientID: googleConfig.serverClientId  // (Web)
        )
        
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                GIDSignIn.sharedInstance.signIn(
                    with: gidConfig,
                    presenting: parent.getRootViewController()!
                ) { user, error in
                    guard error == nil, let user = user else {
                        // If the user canceled the operation, don't display an error
                        if let error = error as? GIDSignInError, error.code == .canceled {
                            return continuation.resume()
                        }
                        
                        Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                            loginStep: .error,
                            signInType: .google
                        ))
                        
                        logger.error("Failed to sign in with Google. Either an error occurred or no user info was provided. Error:  \(String(describing: error))")
                        return continuation.resume()
                    }
                    
                    user.authentication.do { authentication, error in
                        guard error == nil, let authentication = authentication, let idToken = authentication.idToken else {
                            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                                loginStep: .error,
                                signInType: .google
                            ))
                            logger.error("Google sign-in failed. Either no ID token was present, or an error was thrown. Error:  \(String(describing: error))")
                            return continuation.resume()
                        }
                        
                        Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                            loginStep: .completing
                        ))
                        
                        logger.debug("Sign-in handshake with Google completed successfully.")
                        Task {
                            do {
                                let tokenResponse = try await Auth.fetchToken(idToken: idToken, intent: intent)
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
                                            loginStep: .success,
                                            intent: intent,
                                            userType: tokenResponse?.userType
                                        )
                                    )
                                }
                                return continuation.resume()
                            } catch ApiError.generic(let errorInfo) {
                                if errorInfo.code == "E_SIGN_IN_USER_NOT_FOUND" {
                                    Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                                        token: idToken,
                                        loginStep: .noAccount,
                                        intent: .signIn
                                    ))
                                } else {
                                    DispatchQueue.main.async {
                                        Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                                            loginStep: .error,
                                            signInType: .google
                                        ))
                                    }
                                }
                                logger.error("Google sign-in failed during Rownd token exchange. Error: \(String(describing: errorInfo))")
                                return continuation.resume()
                            } catch {
                                Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                                    loginStep: .error,
                                    signInType: .google
                                ))
                                logger.error("Google sign-in failed during Rownd token exchange. Error: \(String(describing: error))")
                                return continuation.resume()
                            }
                        }
                    }
                }
            }
        }
    }
}
