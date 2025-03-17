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
import Combine

private let appleSignInDataKey = "userAppleSignInData"

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
    var cancellables = Set<AnyCancellable>()

    init(_ parent: Rownd) {
        self.parent = parent
        super.init()
    }

    func signIn(_ intent: RowndSignInIntent?) {
        self.intent = intent
        // Create an object of the ASAuthorizationAppleIDProvider
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        // Create a request
        let request = appleIDProvider.createRequest()
        // Define the scope of the request
        request.requestedScopes = [.fullName, .email]
        // Make the request
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])

        // Assigning the delegates
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
            var userAppleSignInData: AppleSignInData? = nil

            if let email = email {
                // Store email and fullName in AppleSignInData struct if available
                userAppleSignInData = AppleSignInData(
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

                Task { [userAppleSignInData] in
                    do {
                        let userData = [
                            "email": AnyCodable(userAppleSignInData?.email),
                            "first_name": AnyCodable(userAppleSignInData?.firstName),
                            "last_name": AnyCodable(userAppleSignInData?.lastName),
                            "full_name": AnyCodable(userAppleSignInData?.fullName),
                        ]

                        let tokenResponse = try await Auth.fetchToken(idToken: idToken, userData: userData, intent: intent)

                        Task { @MainActor in
                            Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                                loginStep: RowndSignInLoginStep.success,
                                intent: self.intent,
                                userType: tokenResponse?.userType,
                                appVariantUserType: tokenResponse?.appVariantUserType
                            ))
                        }

                        // Prevent fast auth handshakes from feeling jarring to the user
                        try await Task.sleep(nanoseconds: UInt64(2 * Double(NSEC_PER_SEC)))

                        DispatchQueue.main.async {
                            Context.currentContext.store.dispatch(Context.currentContext.store.state.auth.onReceiveAppleAuthTokens(
                                AuthState(
                                    accessToken: tokenResponse?.accessToken,
                                    refreshToken: tokenResponse?.refreshToken
                                )
                            ))

                            Context.currentContext.store.dispatch(SetLastSignInMethod(payload: SignInMethodTypes.apple))

                            let subscriber = Context.currentContext.store.subscribe { $0.auth.isAccessTokenValid }
                            subscriber.$current.sink { isAccessTokenValid in
                                if isAccessTokenValid {
                                    subscriber.unsubscribe()
                                    self.updateUserDataWithAppleData(fullName: fullName, email: email)
                                    
                                    RowndEventEmitter.emit(RowndEvent(
                                        event: .signInCompleted,
                                        data: [
                                            "method": AnyCodable(SignInType.apple.rawValue),
                                            "user_type": AnyCodable(tokenResponse?.userType?.rawValue),
                                            "app_variant_user_type": AnyCodable(tokenResponse?.appVariantUserType?.rawValue)
                                        ]
                                    ))
                                }
                            }.store(in: &self.cancellables)
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

    func updateUserDataWithAppleData(fullName: PersonNameComponents?, email: String?) {
        Context.currentContext.store.dispatch(Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            Task {
                do {
                    if let userStateResponse = try await UserData.fetchUserData(state) {
                        var userData = state.user.data
                        userData.merge(userStateResponse.data) { (current, _) in current }

                        let defaults = UserDefaults.standard
                        // use UserDefault values for Email and fullName if available
                        if let userAppleSignInData = defaults.object(forKey: appleSignInDataKey) as? Data {
                            let decoder = JSONDecoder()
                            if let loadedAppleSignInData = try? decoder.decode(AppleSignInData.self, from: userAppleSignInData) {
                                userData["email"] = AnyCodable(loadedAppleSignInData.email)
                                userData["first_name"] = AnyCodable(loadedAppleSignInData.firstName)
                                userData["last_name"] = AnyCodable(loadedAppleSignInData.lastName)
                                userData["full_name"] = AnyCodable(loadedAppleSignInData.fullName)
                            }
                        } else {
                            if let email = email {
                                userData["email"] = AnyCodable(email)
                                userData["first_name"] = AnyCodable(fullName?.givenName)
                                userData["last_name"] = AnyCodable(fullName?.familyName)
                                userData["full_name"] = AnyCodable(String("\(fullName?.givenName) \(fullName?.familyName)"))
                            }
                        }

                        if !userData.isEmpty {
                            dispatch(UserData.save(userData))
                            logger.debug("UserData to save after signin: \(String(describing: userData))")
                        }
                    } else {
                        // Handle the case where userStateResponse is nil
                        logger.error("Failed to fetch user state response")
                    }
                } catch {
                    // Handle any errors that occurred during fetch
                    logger.error("Error fetching user data: \(error)")
                }
            }
        })
    }

    // If authorization faced any issue then this method will get triggered
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {

        // If there is any error will get it here
        logger.error("An error occurred while signing in with Apple. Error: \(String(describing: error))")
        
        func defaultSignInFlow() {
            logger.error("Falling back to default sign flow")
            Rownd.requestSignIn(RowndSignInOptions(intent: intent))
        }

        guard let authorizationError = error as? ASAuthorizationError else {
            defaultSignInFlow()
            return
        }

        switch authorizationError.code {
        case .canceled:
            return
        default:
            defaultSignInFlow()
        }
    }
}
