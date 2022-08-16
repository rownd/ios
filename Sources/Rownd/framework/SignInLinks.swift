//
//  SignInLinks.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/16/22.
//

import Foundation

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

            let authResp: SignInLinkResp = try await RowndApi.client.send(.get(signInUrl.absoluteString)).value

            DispatchQueue.main.async {
                store.dispatch(SetAuthState(payload: AuthState(
                    accessToken: authResp.accessToken,
                    refreshToken: authResp.refreshToken
                )))
            }
        } catch {
            print(error)
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
