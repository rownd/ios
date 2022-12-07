
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The authentication manager object.
*/

import AuthenticationServices
import Foundation
import os
import Get
import LocalAuthentication

extension Data {
    init?(base64EncodedURLSafe string: String, options: Base64DecodingOptions = []) {
        let string = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .padding(toLength: ((string.count+3)/4)*4,
                  withPad: "=",
                  startingAt: 0)

        self.init(base64Encoded: string, options: options)
    }

    func base64URLEncodedString() -> String {
      let string = self.base64EncodedString()
      return string
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    }
}

extension LAContext {
    enum BiometricType: String {
        case none
        case touchID
        case faceID
    }

    var biometricType: BiometricType {
        var error: NSError?

        guard self.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Capture these recoverable error thru Crashlytics
            return .none
        }

        if #available(iOS 11.0, *) {
            switch self.biometryType {
            case .none:
                return .none
            case .touchID:
                return .touchID
            case .faceID:
                return .faceID
            @unknown default:
                return .none
            }
        } else {
            return  self.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ? .touchID : .none
        }
    }
}

enum PasskeyCoordinatorMethods {
    case SignIn
    case SignUp
}

class PasskeyCoordinator: NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    
    var method: PasskeyCoordinatorMethods? = nil
    
    private func getWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
        return scenes.first as? UIWindowScene
    }
    
    private func getHubViewController() -> HubViewController? {
        let bottomSheetController = Rownd.getInstance().bottomSheetController
        if let hubViewController = bottomSheetController.controller as? HubViewController {
            return hubViewController
        }
        return nil
    }
    
    func signUpWith() {
        //Add passkey to the Rownd user
        method = PasskeyCoordinatorMethods.SignUp
        let anchor: ASPresentationAnchor = (getWindowScene()?.windows.last?.rootViewController?.view.window)!
        let hubViewController = getHubViewController()
        
        Task {
            do {
                let challengeResponse: PasskeyRegisterResponse = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/hub/auth/passkeys/registration")!)).value
                
                await hubViewController?.loadNewPage(targetPage: .connectPasskey, jsFnOptions: RowndConnectPasskeySignInOptions(status: Status.loading, biometricType: LAContext().biometricType.rawValue))
                
                let appName = store.state.appConfig.name != nil ? String(describing:store.state.appConfig.name!) : ""
                // Username priority in order First Name, Email, App name
                var userName = appName.isEmpty ? "Add app name to Rownd" : appName
                let email = store.state.user.data["email"] != nil ? String(describing: store.state.user.data["email"]!) : ""
                let firstName = store.state.user.data["first_name"] != nil ? String(describing: store.state.user.data["first_name"]!) : ""

                if !email.isEmpty {
                    userName = email
                }
                if !firstName.isEmpty {
                    userName = firstName
                }

                signUpWith(userName: userName, anchor: anchor, challengeResponse: challengeResponse)
            }
            catch {
                logger.error("Failed to fetch passkey registration challenge: \(String(describing: error))")
                await hubViewController?.loadNewPage(targetPage: .connectPasskey, jsFnOptions: RowndConnectPasskeySignInOptions(status: Status.failed, biometricType: LAContext().biometricType.rawValue))
            }
        }
    }
    
    func signInWith() {
        //Use passkey to sign in as a Rownd user
        method = PasskeyCoordinatorMethods.SignIn
        let anchor: ASPresentationAnchor = (getWindowScene()?.windows.last?.rootViewController?.view.window)!
        Task {
            do {
                let challengeResponse: PasskeyAuthenticationResponse = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/hub/auth/passkeys/authentication")!)).value
                signInWith(anchor: anchor, preferImmediatelyAvailableCredentials: false, challengeResponse: challengeResponse)
            }
            catch {
                logger.error("Failed to fetch passkey challenge: \(String(describing: error))")
            }
        }
    }

    func signInWith(anchor: ASPresentationAnchor, preferImmediatelyAvailableCredentials: Bool, challengeResponse: PasskeyAuthenticationResponse) {
        guard let subdomain = store.state.appConfig.config?.subdomain else {
            logger.trace("Please go to the Rownd dashboard https://app.rownd.io/applications and add a subdomain in mobile sign-in")
            return
        }
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: subdomain + Rownd.config.subdomainExtension)

        let challenge = Data(base64EncodedURLSafe: challengeResponse.challenge)!

        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

        // Also allow the user to use a saved password, if they have one.
        let passwordCredentialProvider = ASAuthorizationPasswordProvider()
        let passwordRequest = passwordCredentialProvider.createRequest()

        // Pass in any mix of supported sign-in request types.
        let authController = ASAuthorizationController(authorizationRequests: [ assertionRequest, passwordRequest ] )
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()

    }
    
    func signUpWith(userName: String, anchor: ASPresentationAnchor, challengeResponse: PasskeyRegisterResponse) {
        guard let subdomain = store.state.appConfig.config?.subdomain else {
            logger.trace("Please go to the Rownd dashboard https://app.rownd.io/applications and add a subdomain in mobile sign-in")
            return
        }
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: subdomain + Rownd.config.subdomainExtension)
        
        let challenge = Data(base64EncodedURLSafe: challengeResponse.challenge)!
        let userID = Data(challengeResponse.user.id.utf8)

        let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: userName, userID: userID)

        let authController = ASAuthorizationController(authorizationRequests: [ registrationRequest ] )
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:

            let attestationObject = credentialRegistration.rawAttestationObject
            let clientDataJSON = credentialRegistration.rawClientDataJSON
            let credentialID = credentialRegistration.credentialID.base64URLEncodedString()
            
            let hubViewController = getHubViewController()

            Task {
                let body: PasskeyRegisterPayload = PasskeyRegisterPayload(response: PasskeyRegisterPayloadResponse(attestationObject: attestationObject?.base64URLEncodedString() ?? "", clientDataJSON: clientDataJSON.base64URLEncodedString()), id: credentialID, rawId: credentialID)

                do {
                    let _ = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/hub/auth/passkeys/registration")!, method: "post", body: body, headers: ["content-type":"application/json"] )).value
                    await hubViewController?.loadNewPage(targetPage: .connectPasskey, jsFnOptions: RowndConnectPasskeySignInOptions(status: Status.success, biometricType: LAContext().biometricType.rawValue))
                } catch {
                    logger.error("Failed passkey POST registration: \(String(describing: error))")
                    await hubViewController?.loadNewPage(targetPage: .connectPasskey, jsFnOptions: RowndConnectPasskeySignInOptions(status: Status.failed, biometricType: LAContext().biometricType.rawValue))
                }
            }
        case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            let signature = credentialAssertion.signature
            let clientDataJSON = credentialAssertion.rawClientDataJSON
            let userId = credentialAssertion.userID
            let credentialID = credentialAssertion.credentialID.base64URLEncodedString()
            let authenticatorData = credentialAssertion.rawAuthenticatorData
            
            Task {
                let body: PasskeyAuthenticationPayload = PasskeyAuthenticationPayload(response: PasskeyAuthenticationPayloadResponse(clientDataJSON: clientDataJSON.base64URLEncodedString(), signature: signature?.base64URLEncodedString() ?? "", userHandle: userId?.base64URLEncodedString() ?? "", authenticatorData: authenticatorData?.base64URLEncodedString() ?? ""), rawId: credentialID, id: credentialID)

                do {
                    let challengeAuthenticationCompleteResponse: PasskeyAuthenticationCompleteResponse = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/hub/auth/passkeys/authentication")!, method: "post", body: body, headers: ["content-type":"application/json"] )).value
                    
                    DispatchQueue.main.async {
                        store.dispatch(SetAuthState(payload: AuthState(accessToken: challengeAuthenticationCompleteResponse.access_token, refreshToken: challengeAuthenticationCompleteResponse.refresh_token)))
                        store.dispatch(UserData.fetch())
                    }
                } catch {
                    logger.error("Failed passkey POST registration: \(String(describing: error))")
                }
            }
            
        case let passwordCredential as ASPasswordCredential:
            logger.log("A password was provided: \(passwordCredential)")
            // Verify the userName and password with your service.
            // let userName = passwordCredential.user
            // let password = passwordCredential.password

            // After the server verifies the userName and password, sign in the user.
            // didFinishSignIn()
        default:
            fatalError("Received unknown authorization type.")
        }

    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let hubViewController = getHubViewController()
        
        guard let authorizationError = error as? ASAuthorizationError else {
            logger.error("Unexpected authorization error: \(error.localizedDescription)")
            if (method == PasskeyCoordinatorMethods.SignUp) {
                hubViewController?.loadNewPage(targetPage: .connectPasskey, jsFnOptions: RowndConnectPasskeySignInOptions(status: Status.failed, biometricType: LAContext().biometricType.rawValue))
            }
            return
        }

        if authorizationError.code == .canceled {
            // Either the system doesn't find any credentials and the request ends silently, or the user cancels the request.
            // This is a good time to show a traditional login form, or ask the user to create an account.
            logger.log("Request canceled.")
            hubViewController?.dismiss(animated: true)

        } else {
            logger.error("Error: \((error as NSError).userInfo)")
            if (method == PasskeyCoordinatorMethods.SignUp) {
                hubViewController?.loadNewPage(targetPage: .connectPasskey, jsFnOptions: RowndConnectPasskeySignInOptions(status: Status.failed, biometricType: LAContext().biometricType.rawValue))
            }
        }

    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let vc = windowScene?.windows.last?.rootViewController
        return (vc?.view.window!)!
    }


}

struct PasskeyRegisterResponse: Hashable, Codable {
    public var challenge: String
    public var user: PasskeyRegisterResponseUser

    enum CodingKeys: String, CodingKey {
        case challenge, user
    }
}

public struct PasskeyRegisterResponseUser: Hashable {
    public var id: String
}

extension PasskeyRegisterResponseUser: Codable {
    enum CodingKeys: String, CodingKey {
        case id
    }
}

struct PasskeyRegisterPayload: Hashable, Codable {
    public var response: PasskeyRegisterPayloadResponse
    public var id: String
    public var rawId: String
    public var type: String = "public-key"

    enum CodingKeys: String, CodingKey {
        case response, id, rawId, type
    }
}

public struct PasskeyRegisterPayloadResponse: Hashable {
    public var attestationObject: String
    public var clientDataJSON: String
}

extension PasskeyRegisterPayloadResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case attestationObject, clientDataJSON
    }
}


struct PasskeyAuthenticationResponse: Hashable, Codable {
    public var challenge: String

    enum CodingKeys: String, CodingKey {
        case challenge
    }
}

struct PasskeyAuthenticationPayload: Hashable, Codable {
    public var response: PasskeyAuthenticationPayloadResponse
    public var rawId: String
    public var id: String
    public var type: String = "public-key"

    enum CodingKeys: String, CodingKey {
        case response, rawId, id, type
    }
}

public struct PasskeyAuthenticationPayloadResponse: Hashable {
    public var clientDataJSON: String
    public var signature: String
    public var userHandle: String
    public var authenticatorData: String
}

extension PasskeyAuthenticationPayloadResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case clientDataJSON, signature, userHandle, authenticatorData
    }
}


struct PasskeyAuthenticationCompleteResponse: Hashable, Codable {
    public var verified: Bool
    public var access_token: String
    public var refresh_token: String

    enum CodingKeys: String, CodingKey {
        case verified, access_token, refresh_token
    }
}
