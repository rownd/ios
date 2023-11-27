//
//  SignInLinks.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/16/22.
//

import Foundation
import Get
import JWTDecode

struct SignInLinkResp: Hashable, Codable {
    public var accessToken: String?
    public var refreshToken: String?
    public var appId: String?
    public var appUserId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case appId = "app_id"
        case appUserId = "app_user_id"
    }
}

class SignInLinks {
    static func signInWithLink(_ url: URL) async throws {
        do {
            var signInUrl = url
            if let fragment = signInUrl.fragment {
                signInUrl = URL(string: signInUrl.absoluteString.replacingOccurrences(of: "#\(fragment)", with: "")) ?? signInUrl
            }

            let authResp: SignInLinkResp = try await Rownd.apiClient.send(Request(url: signInUrl)).value

            
            /// If the sign-in link completed with a Platform JWT, save it and enable mobile app tagging if requested
            if let accessToken = authResp.accessToken {
                let jwt = try decode(jwt: accessToken)
                if jwt.claim(rowndClaim: RowndJWTClaim.isPlatformJwt).boolean == true {
                    Rownd.actionOverlay.setPlatformAccessToken(accessToken)
                    
                    let showActionOverlay = signInUrl.value(forQueryParam: "show_action_overlay")
                    let webSocketURL = signInUrl.value(forQueryParam: "web_socket_url")
                    
                    guard let showActionOverlay = showActionOverlay else {
                        return
                    }
                    
                    guard let webSocketURL = webSocketURL else {
                        logger.warning("missing web_socket_url query param in sign-in link")
                        return
                    }
                    
                    if showActionOverlay != "true" || webSocketURL == "" {
                        return
                    }
                    
                    Task { @MainActor in
                        Rownd.showActionOverlay()
                        do {
                            try Rownd.actionOverlay.connect(webSocketURL)
                        } catch {
                            logger.error("Failed to show action overlay. Unable to connect to web socket: \(String(describing: error))")
                        }
                    }
                    return
                }
            }
            
            if store.state.auth.isAuthenticated {
                return
            }

            Task { @MainActor in
                store.dispatch(SetAuthState(payload: AuthState(
                    accessToken: authResp.accessToken,
                    refreshToken: authResp.refreshToken
                )))

                store.dispatch(UserData.fetch())
                
                store.dispatch(PasskeyData.fetchPasskeyRegistration())
            }
        } catch {
            logger.error("Auto sign-in failed: \(String(describing: error))")
            throw SignInError("Auto sign-in failed: \(error.localizedDescription)")
        }
    }
}

struct SignInError: Error, CustomStringConvertible {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}
