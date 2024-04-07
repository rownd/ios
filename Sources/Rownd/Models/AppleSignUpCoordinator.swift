//
//  AppleSignUpCoordinator.swift
//  appleSignIn
//
//  Created by Michael Murray on 7/17/22.
//

import SwiftUI
import AuthenticationServices
import UIKit
import AnyCodable
import ReSwiftThunk

fileprivate let appleSignInDataKey = "userAppleSignInData"

struct AppleSignInData: Codable {
    var email: String
    var firstName: String?
    var lastName: String?
    var fullName: String?
    
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case email = "email"
        case fullName = "full_name"
    }
}

class AppleSignUpCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var parent: Rownd?
    var intent: RowndSignInIntent?
    
    init(_ parent: Rownd) {
        self.parent = parent
        super.init()
    }
    
    func signIn(_ intent: RowndSignInIntent?) {
        self.intent = intent
        //Create an object of the ASAuthorizationAppleIDProvider
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        //Create a request
        let request = appleIDProvider.createRequest()
        //Define the scope of the request
        request.requestedScopes = [.fullName, .email]
        //Make the request
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        
        //Assigning the delegates
        authorizationController.presentationContextProvider = self
        authorizationController.delegate = self
        authorizationController.performRequests()
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let vc = UIApplication.shared.windows.last?.rootViewController
        return (vc?.view.window!)!
    }
    
    private func getFullName(firstName: String?, lastName: String?) -> String {
        return String("\(firstName ?? "") \(lastName ?? "")")
    }
    
    // If authorization is successful then this method will get triggered
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        
        DispatchQueue.main.async {
            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                loginStep: .completing
            ))
        }
        
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            
            // Create an account in your system.
            // let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            let identityToken = appleIDCredential.identityToken
            
            if let email = email {
                //Store email and fullName in AppleSignInData struct if available
                let userAppleSignInData = AppleSignInData(
                    email: email,
                    firstName: fullName?.givenName,
                    lastName: fullName?.familyName,
                    fullName: getFullName(firstName: fullName?.givenName, lastName: fullName?.familyName)
                )
                let encoder = JSONEncoder()
                if let encoded = try? encoder.encode(userAppleSignInData) {
                    let defaults = UserDefaults.standard
                    defaults.set(encoded, forKey: appleSignInDataKey)
                }
            }
            
            if let identityToken = identityToken,
               let urlContent = NSString(data: identityToken, encoding: String.Encoding.ascii.rawValue) {
                let idToken = urlContent as String
                
                Task {
                    do {
                        let tokenResponse = try await Auth.fetchToken(idToken: idToken, intent: intent)
                        
                        Task { @MainActor in
                            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                                loginStep: RowndSignInLoginStep.success,
                                intent: self.intent,
                                userType: tokenResponse?.userType
                            ))
                        }
                        
                        // Prevent fast auth handshakes from feeling jarring to the user
                        try await Task.sleep(nanoseconds: UInt64(2 * Double(NSEC_PER_SEC)))
                        
                        DispatchQueue.main.async {
                            Context.currentContext.store.dispatch(Context.currentContext.store.state.auth.onReceiveAuthTokens(
                                AuthState(
                                    accessToken: tokenResponse?.accessToken,
                                    refreshToken: tokenResponse?.refreshToken
                                )
                            ))
                            
                            Context.currentContext.store.dispatch(SetLastSignInMethod(payload: SignInMethodTypes.apple))
                            
                            Context.currentContext.store.dispatch(Thunk<RowndState> { dispatch, getState in
                                guard let state = getState() else { return }
                                
                                var userData = state.user.data
                                
                                let defaults = UserDefaults.standard
                                //use UserDefault values for Email and fullName if available
                                if let userAppleSignInData = defaults.object(forKey: appleSignInDataKey) as? Data {
                                    let decoder = JSONDecoder()
                                    if let loadedAppleSignInData = try? decoder.decode(AppleSignInData.self, from: userAppleSignInData) {
                                        userData["email"] = AnyCodable.init(loadedAppleSignInData.email)
                                        userData["first_name"] = AnyCodable.init(loadedAppleSignInData.firstName)
                                        userData["last_name"] = AnyCodable.init(loadedAppleSignInData.lastName)
                                        userData["full_name"] = AnyCodable.init(loadedAppleSignInData.fullName)
                                    }
                                } else {
                                    if let email = email {
                                        userData["email"] = AnyCodable.init(email)
                                        userData["first_name"] = AnyCodable.init(fullName?.givenName)
                                        userData["last_name"] = AnyCodable.init(fullName?.familyName)
                                        userData["full_name"] = AnyCodable.init(String("\(fullName?.givenName) \(fullName?.familyName)"))
                                    }
                                }
                                
                                if (!userData.isEmpty) {
                                    DispatchQueue.main.async {
                                        dispatch(UserData.save(userData))
                                    }
                                }
                            })
                        }
                    } catch ApiError.generic(let errorInfo) {
                        if errorInfo.code == "E_SIGN_IN_USER_NOT_FOUND" {
                            Task { @MainActor in
                                Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                                    token: idToken,
                                    loginStep: .noAccount,
                                    intent: .signIn
                                ))
                            }
                        } else {
                            DispatchQueue.main.async {
                                Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                                    loginStep: .error,
                                    signInType: .apple
                                ))
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                                loginStep: .error,
                                signInType: .apple
                            ))
                        }
                    }
                }
            } else {
                logger.error("Missing data from Apple sign-in response: \(String(describing: appleIDCredential))")
                Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                    loginStep: .error,
                    signInType: .apple
                ))
            }
            
        default:
            logger.error("Unknown credential type returned from Apple ID sign-in: \(String(describing: authorization.credential))")
            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                loginStep: .error,
                signInType: .apple
            ))
            break
        }
    }
    
    //If authorization faced any issue then this method will get triggered
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        
        //If there is any error will get it here
        logger.error("An error occurred while signing in with Apple. Error: \(String(describing: error))")
        
        guard let authorizationError = error as? ASAuthorizationError else {
            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                loginStep: .error,
                signInType: .apple
            ))
            return
        }
        
        switch authorizationError.code {
        case .canceled:
            return
        default:
            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                loginStep: .error,
                signInType: .apple
            ))
        }
    }
}


