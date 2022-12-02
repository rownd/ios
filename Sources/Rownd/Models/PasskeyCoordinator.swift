
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

class PasskeyCoordinator: NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
//    private func getRootViewController() -> UIViewController? {
//        return UIApplication.shared.connectedScenes
//            .filter({$0.activationState == .foregroundActive})
//            .compactMap({$0 as? UIWindowScene})
//            .first?.windows
//            .filter({$0.isKeyWindow}).first?.rootViewController
//    }
    
    func signUpWith() {
        //Add passkey to the Rownd user
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let vc = windowScene?.windows.last?.rootViewController
        let anchor: ASPresentationAnchor = (vc?.view.window)!
        Task {
            do {
                let challengeResponse: ChallengeRegisterResp = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/hub/auth/passkeys/registration")!)).value
                
                
//                let rootViewController = getRootViewController()
//                await rootViewController?.dismissBottomSheet()
//                let hubController = await HubViewController()
//                await hubController.hubWebController.dismissBottomSheet()
                
                signUpWith(userName: store.state.appConfig.name ?? "", anchor: anchor, challengeResponse: challengeResponse)
            }
            catch {
                logger.error("Failed to fetch passkey registration challenge: \(String(describing: error))")
            }
        }
    }
    
    func signInWith() {
        //Use passkey to sign in as a Rownd user
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let vc = windowScene?.windows.last?.rootViewController
        let anchor: ASPresentationAnchor = (vc?.view.window)!
        Task {
            do {
                let challengeResponse: ChallengeRegisterResp = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/hub/auth/passkeys/registration")!)).value
                signInWith(anchor: anchor, preferImmediatelyAvailableCredentials: false, challengeResponse: challengeResponse)
            }
            catch {
                logger.error("Failed to fetch passkey challenge: \(String(describing: error))")
            }
        }
    }

    func signInWith(anchor: ASPresentationAnchor, preferImmediatelyAvailableCredentials: Bool, challengeResponse: ChallengeRegisterResp) {
        guard let subdomain = store.state.appConfig.config?.subdomain else {
            logger.trace("Please go to the Rownd dashboard https://app.rownd.io/applications and add a subdomain in mobile sign-in")
            return
        }
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: subdomain + Rownd.config.subdomainExtension)

        // Fetch the challenge from the server. The challenge needs to be unique for each request.
        let challenge = Data()

        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

        // Also allow the user to use a saved password, if they have one.
        let passwordCredentialProvider = ASAuthorizationPasswordProvider()
        let passwordRequest = passwordCredentialProvider.createRequest()

        // Pass in any mix of supported sign-in request types.
        let authController = ASAuthorizationController(authorizationRequests: [ assertionRequest, passwordRequest ] )
        authController.delegate = self
        authController.presentationContextProvider = self

        if preferImmediatelyAvailableCredentials {
            // If credentials are available, presents a modal sign-in sheet.
            // If there are no locally saved credentials, no UI appears and
            // the system passes ASAuthorizationError.Code.canceled to call
            // `AccountManager.authorizationController(controller:didCompleteWithError:)`.
            if #available(iOS 16.0, *) {
                authController.performRequests(options: .preferImmediatelyAvailableCredentials)
            } else {
                print("UNAVAILABLE BELOW iOS 16")
            }
        } else {
            // If credentials are available, presents a modal sign-in sheet.
            // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
            // passkey from a nearby device.
            authController.performRequests()
        }

    }
    
    func signUpWith(userName: String, anchor: ASPresentationAnchor, challengeResponse: ChallengeRegisterResp) {
        guard let subdomain = store.state.appConfig.config?.subdomain else {
            logger.trace("Please go to the Rownd dashboard https://app.rownd.io/applications and add a subdomain in mobile sign-in")
            return
        }
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: subdomain + Rownd.config.subdomainExtension)
        
        // The userID is the identifier for the user's account.
        let challenge = Data(base64EncodedURLSafe: challengeResponse.challenge)!
        let userID = Data(challengeResponse.user.id.utf8)

        let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: userName, userID: userID)

        // Use only ASAuthorizationPlatformPublicKeyCredentialRegistrationRequests or
        // ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequests here.
        let authController = ASAuthorizationController(authorizationRequests: [ registrationRequest ] )
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("SUCCESSFUL SIGN UP")
        
        let logger = Logger()
        switch authorization.credential {
        case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            logger.log("A new passkey was registered: \(credentialRegistration)")
            // Verify the attestationObject and clientDataJSON with your service.
            // The attestationObject contains the user's new public key to store and use for subsequent sign-ins.
            let attestationObject = credentialRegistration.rawAttestationObject
            let clientDataJSON = credentialRegistration.rawClientDataJSON
            let credentialID = credentialRegistration.credentialID.base64URLEncodedString()

            Task {
                let body: ChallengeRegisterPayload = ChallengeRegisterPayload(response: ChallengeRegisterPayloadResponse(attestationObject: attestationObject?.base64URLEncodedString() ?? "", clientDataJSON: clientDataJSON.base64URLEncodedString()), id: credentialID, rawId: credentialID)

                do {
                    let _ = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/hub/auth/passkeys/registration")!, method: "post", body: body, headers: ["content-type":"application/json"] )).value
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                        let _ = self.parent?.displayHub(.connectPasskey, jsFnOptions: RowndConnectPasskeySignInOptions(success: true, biometricType: LAContext().biometricType.rawValue))
                    }
                } catch {
                    logger.error("Failed passkey POST registration: \(String(describing: error))")
                }
            }
        case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            // Verify the below signature and clientDataJSON with your service for the given userID.
            let signature = credentialAssertion.signature
            let clientDataJSON = credentialAssertion.rawClientDataJSON
            _ = credentialAssertion.userID ?? Data()
            
            print("clientDataJSON \(clientDataJSON.base64EncodedString())")
            print("signature \(String(describing: signature?.base64EncodedString()))")
            // After the server verifies the assertion, sign in the user.
            // didFinishSignIn()
        case let passwordCredential as ASPasswordCredential:
            print("LOGGED IN")
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
        print("COMPLETED WITH AN ERROR")
        let logger = Logger()
        guard let authorizationError = error as? ASAuthorizationError else {
            logger.error("Unexpected authorization error: \(error.localizedDescription)")
            return
        }

        if authorizationError.code == .canceled {
            // Either the system doesn't find any credentials and the request ends silently, or the user cancels the request.
            // This is a good time to show a traditional login form, or ask the user to create an account.
            logger.log("Request canceled.")

        } else {
            // Another ASAuthorization error.
            // Note: The userInfo dictionary contains useful information.
            logger.error("Error: \((error as NSError).userInfo)")
        }

    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let vc = windowScene?.windows.last?.rootViewController
        return (vc?.view.window!)!
    }


}

struct ChallengeRegisterResp: Hashable, Codable {
    public var challenge: String
    public var user: ChallengeRegisterResponseUser

    enum CodingKeys: String, CodingKey {
        case challenge, user
    }
}

public struct ChallengeRegisterResponseUser: Hashable {
    public var id: String
}

extension ChallengeRegisterResponseUser: Codable {
    enum CodingKeys: String, CodingKey {
        case id
    }
}

struct ChallengeRegisterPayload: Hashable, Codable {
    public var response: ChallengeRegisterPayloadResponse
    public var id: String
    public var rawId: String
    public var type: String = "public-key"

    enum CodingKeys: String, CodingKey {
        case response, id, rawId, type
    }
}

public struct ChallengeRegisterPayloadResponse: Hashable {
    public var attestationObject: String
    public var clientDataJSON: String
}

extension ChallengeRegisterPayloadResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case attestationObject, clientDataJSON
    }
}
