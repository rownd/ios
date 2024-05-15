//
//  GoogleSignInCoordinator.swift
//  Rownd
//
//  Created by Matt Hamann on 4/4/23.
//

import Foundation
import GoogleSignIn
import UIKit
import AnyCodable

class GoogleSignInCoordinator: NSObject {
    var parent: Rownd
    var intent: RowndSignInIntent?

    init(_ parent: Rownd) {
        self.parent = parent
        super.init()
    }

    func signIn(_ intent: RowndSignInIntent?) async {
        await signIn(intent, hint: nil)
    }

    func signIn(_ intent: RowndSignInIntent?, hint: String?) async {
        let googleConfig = Context.currentContext.store.state.appConfig.config?.hub?.auth?.signInMethods?.google
        guard googleConfig?.enabled == true, let googleConfig = googleConfig else {
            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                loginStep: .error,
                signInType: .google
            ))
            return logger.error("Sign in with Google is not enabled. Turn it on in the Rownd platform")
        }

        if googleConfig.serverClientId == nil ||
            googleConfig.serverClientId == "" ||
            googleConfig.iosClientId == nil ||
            googleConfig.iosClientId == "" {
            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                loginStep: .error,
                signInType: .google
            ))
            return logger.error("Cannot sign in with Google. Missing client configuration")
        }

        let reversedClientId = googleConfig.iosClientId!.split(separator: ".").reversed().joined(separator: ".")
        if let url = NSURL(string: reversedClientId + "://") {
            if await UIApplication.shared.canOpenURL(url as URL) == false {
                Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                    loginStep: .error,
                    signInType: .google
                ))
                return logger.error("Cannot sign in with Google. \(String(describing: reversedClientId)) is not defined in URL schemes")
            }
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: (googleConfig.iosClientId)!,   // (IOS)
            serverClientID: googleConfig.serverClientId  // (Web)
        )

        Task { @MainActor in
            guard let rootViewController = parent.getRootViewController() else {
                logger.error("Failed to retrieve root view controller")
                return
            }

            do {
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: rootViewController,
                    hint: hint
                )

                guard let idToken = result.user.idToken else {
                    Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                        loginStep: .error,
                        signInType: .google
                    ))
                    logger.error("Google sign-in failed. Either no ID token was present, or an error was thrown.")
                    return
                }

                Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                    loginStep: .completing
                ))

                logger.debug("Sign-in handshake with Google completed successfully.")
                do {
                    let tokenResponse = try await Auth.fetchToken(idToken: idToken.tokenString, intent: intent)
                    DispatchQueue.main.async {
                        Context.currentContext.store.dispatch(SetAuthState(
                            payload: AuthState(
                                accessToken: tokenResponse?.accessToken,
                                refreshToken: tokenResponse?.refreshToken
                            )
                        ))
                        Context.currentContext.store.dispatch(UserData.fetch())
                        Context.currentContext.store.dispatch(SetLastSignInMethod(payload: SignInMethodTypes.google))

                        Rownd.requestSignIn(
                            jsFnOptions: RowndSignInJsOptions(
                                loginStep: .success,
                                intent: intent,
                                userType: tokenResponse?.userType
                            )
                        )

                        RowndEventEmitter.emit(RowndEvent(
                            event: .signInCompleted,
                            data: [
                                "method": AnyCodable(SignInType.google.rawValue),
                                "user_type": AnyCodable(tokenResponse?.userType?.rawValue)
                            ]
                        ))
                    }
                    return
                } catch ApiError.generic(let errorInfo) {
                    if errorInfo.code == "E_SIGN_IN_USER_NOT_FOUND" {
                        Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                            token: idToken.tokenString,
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
                    return
                } catch {
                    Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                        loginStep: .error,
                        signInType: .google
                    ))
                    logger.error("Google sign-in failed during Rownd token exchange. Error: \(String(describing: error))")
                    return
                }
            }
        }
    }
}
