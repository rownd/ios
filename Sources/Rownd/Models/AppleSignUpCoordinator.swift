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

class AppleSignUpCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var parent: Rownd?
    
    init(_ parent: Rownd) {
        self.parent = parent
        super.init()
    }
    
    @objc func didTapButton() {
        //Create an object of the ASAuthorizationAppleIDProvider
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        //Create a request
        let request         = appleIDProvider.createRequest()
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
    
    //If authorization is successful then this method will get triggered
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            
            // Create an account in your system.
            //let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            let identityToken = appleIDCredential.identityToken
            
            if let email = email {
                saveKeychainItem(item: email, key: "email")
            }
            if let givenName = fullName?.givenName {
                saveKeychainItem(item: givenName, key: "givenName")
            }
            if let familyName = fullName?.familyName {
                saveKeychainItem(item: familyName, key: "familyName")
            }
            
            if let identityToken = identityToken,
               let urlContent = NSString(data: identityToken, encoding: String.Encoding.ascii.rawValue) {
                let idToken = urlContent as String
                Auth.fetchToken(idToken: idToken) { authState in
                    store.dispatch(SetAuthState(payload: AuthState(accessToken: authState?.accessToken, refreshToken: authState?.refreshToken)))
                    var userData = store.state.user.data
                    let emailKeychain = readKeychainItem(key: "email")
                    let givenNameKeychain = readKeychainItem(key: "givenName")
                    let familyNameKeychain = readKeychainItem(key: "familyName")
                    
                    if let email = email {
                        userData["email"] = AnyCodable.init(email)
                    }
                    if !emailKeychain.isEmpty {
                        // If Rownd failed on first Apple Sign in, the email will be saved in the keychain
                        userData["email"] = AnyCodable.init(emailKeychain)
                    }

                    if let givenName = fullName?.givenName {
                        userData["first_name"] = AnyCodable.init(givenName)
                    }
                    if !givenNameKeychain.isEmpty {
                        // If Rownd failed on first Apple Sign in, the givenName will be saved in the keychain
                        userData["first_name"] = AnyCodable.init(givenNameKeychain)
                    }

                    if let familyName = fullName?.familyName {
                        userData["last_name"] = AnyCodable.init(familyName)
                    }
                    if !familyNameKeychain.isEmpty {
                        // If Rownd failed on first Apple Sign in, the family name will be saved in the keychain
                        userData["last_name"] = AnyCodable.init(familyNameKeychain)
                    }
                    
                    store.dispatch(UserData.save(userData))
                }
            } else {
                logger.trace("apple sign credential alternative")
            }
            
        default:
            logger.trace("apple sign credential break")
            break
        }
    }
    
    //If authorization faced any issue then this method will get triggered
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        
        //If there is any error will get it here
        logger.error("An error occurred while signing in with Apple. Error: \(String(describing: error))")
    }
}


