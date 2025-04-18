//
//  Auth.swift
//  framework
//
//  Created by Matt Hamann on 6/25/22.
//

import Foundation
import UIKit
import ReSwift
import ReSwiftThunk
import JWTDecode
import Get
import AnyCodable

public struct AuthState: Hashable, CustomStringConvertible {
    public var isLoading: Bool = false
    public var accessToken: String?
    public var refreshToken: String?
    public var isVerifiedUser: Bool?
    public var hasPreviouslySignedIn: Bool? = false
    public var userId: String?
    public var challengeId: String?
    public var userIdentifier: String?

    public var description: String {
        return "AuthState(isLoading: \(isLoading), isAuthenticated: \(isAuthenticated), accessToken: \(isAuthenticated ? "[REDACTED]" : "nil"), refreshToken: \(isAuthenticated ? "[REDACTED]" : "nil"), userId: \(userId ?? "nil"), challengeId: \(challengeId ?? "nil"), userIdentifier: \(userIdentifier ?? "nil"))"
    }
}

extension AuthState: Codable {
    public var isAuthenticated: Bool {
        return accessToken != nil
    }

    public var isAuthenticatedWithUserData: Bool {
        if (!isAuthenticated) {
            return false
        }

        let userId = Context.currentContext.store.state.user.data["user_id"]

        return userId != nil
    }

    public var isAccessTokenValid: Bool {
        guard let accessToken = accessToken, !isLoading, Context.currentContext.store.state.clockSyncState != .waiting else {
            return false
        }

        do {
            let jwt = try decode(jwt: accessToken)

            let currentDate = NetworkTimeManager.shared.currentTime ?? Date()
            guard let expiresAt = jwt.expiresAt, let currentDateWithMargin = Calendar.current.date(byAdding: .second, value: 60, to: currentDate) else {
                return false
            }

            return !jwt.ntpExpired && (currentDateWithMargin < expiresAt)
        } catch {
            return false
        }
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case isVerifiedUser = "is_verified_user"
        case hasPreviouslySignedIn = "has_previously_signed_in"
        case challengeId = "challenge_id"
        case userIdentifier = "user_identifier"
    }

    func toRphInitHash() -> String? {
        let userId: String? = Context.currentContext.store.state.user.get(field: "user_id") as? String ?? nil
        let rphInit = [
            "access_token": self.accessToken,
            "refresh_token": self.refreshToken,
            "app_id": Context.currentContext.store.state.appConfig.id,
            "app_user_id": userId
        ]

        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(rphInit)

            return encoded.base64EncodedString()
        } catch {
            logger.error("Failed to build rph_init hash string: \(String(describing: error))")
            return nil
        }
    }

    func getAccessToken(throwIfMissing: Bool) async throws -> String? {
        do {
            let authState = try await Context.currentContext.authenticator.getValidToken()
            return authState.accessToken
        } catch {
            logger.warning("Failed to retrieve access token: \(String(describing: error))")

            if throwIfMissing {
                throw error
            }

            switch error as? AuthenticationError {
            case
                .networkConnectionFailure,
                .serverError:
                throw error

            default: break
            }

            return nil
        }
    }

func onReceiveAuthTokens(_ newAuthState: AuthState) -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let _ = getState() else { return }

            Task {
                // This is a special case to get the new auth state over
                // to the authenticator as quickly as possible without
                // waiting for the store update flow to complete

                DispatchQueue.main.async {
                    dispatch(SetAuthState(payload: newAuthState))
                    dispatch(UserData.fetch())
                    dispatch(PasskeyData.fetchPasskeyRegistration())
                }
            }

        }
    }

    func onReceiveAppleAuthTokens(_ newAuthState: AuthState) -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let _ = getState() else { return }

            Task {
                // This is a special case to get the new auth state over
                // to the authenticator as quickly as possible without
                // waiting for the store update flow to complete

                DispatchQueue.main.async {
                    dispatch(SetAuthState(payload: newAuthState))
                    dispatch(PasskeyData.fetchPasskeyRegistration())
                }
            }

        }
    }
}

// MARK: Reducers

struct SetAuthState: Action {
    var payload = AuthState()
}

func authReducer(action: Action, state: AuthState?) -> AuthState {
    var state = state ?? AuthState()

    let hasPreviouslySignedIn = state.hasPreviouslySignedIn

    switch action {
    case let action as SetAuthState:
        state = action.payload
    case let action as SetUserData:
        state.userId = action.data["user_id"]?.value as? String
    case let action as SetUserState:
        state.userId = action.payload.data["user_id"]?.value as? String
    default:
        break
    }

    if hasPreviouslySignedIn ?? false || state.isAuthenticated {
        state.hasPreviouslySignedIn = true
    }

    return state
}

// MARK: Token / auth API calls

public enum UserType: String, Codable {
    case NewUser = "new_user"
    case ExistingUser = "existing_user"
    case Unknown = "unknown"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = UserType(rawValue: rawValue) ?? .Unknown
    }
}

struct SignOutRequest: Codable {
    var signOutAll: Bool

    enum CodingKeys: String, CodingKey {
        case signOutAll = "sign_out_all"
    }
}

typealias TokenRequestUserData = [String: AnyCodable?]

struct TokenRequest: Codable {
    var refreshToken: String?
    var idToken: String?
    var appId: String?
    var intent: RowndSignInIntent?
    var intentMismatchBehavior: String?
    var userData: TokenRequestUserData?
    var instantUserId: String?

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case appId = "app_id"
        case intentMismatchBehavior = "intent_mismatch_behavior"
        case intent
        case userData = "user_data"
        case instantUserId = "instant_user_id"
    }
}

struct TokenResponse: Codable {
    var refreshToken: String?
    var accessToken: String?
    var userType: UserType?
    var appVariantUserType: UserType?

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case accessToken = "access_token"
        case userType = "user_type"
        case appVariantUserType = "app_variant_user_type"
    }
}

struct TokenResource: APIResource {

    var headers: [String: String]?

    typealias ModelType = TokenResponse

    var methodPath: String {
        return "/hub/auth/token"
    }
}

class Auth {
    static func fetchToken(_ token: String) async throws -> TokenResponse? {
        return try await fetchToken(idToken: token, userData: nil, intent: nil)
    }

    static func fetchToken(idToken: String, userData: TokenRequestUserData?, intent: RowndSignInIntent?) async throws -> TokenResponse? {
        guard let appId = Context.currentContext.store.state.appConfig.id else { return nil }
        let tokenRequest = TokenRequest(
            idToken: idToken,
            appId: appId,
            intent: intent,
            intentMismatchBehavior: "throw",
            userData: userData
        )
        return try await fetchToken(tokenRequest: tokenRequest)
    }

    static func fetchToken(tokenRequest: TokenRequest) async throws -> TokenResponse {
        var tokenRequest = tokenRequest
        if Context.currentContext.store.state.user.authLevel == .instant {
            tokenRequest.instantUserId = Context.currentContext.store.state.user.data["user_id"]?.value as? String
        }

        let tokenResp: Response<TokenResponse> = try await rowndApi.send(Request(
            path: "/hub/auth/token",
            method: .post,
            body: tokenRequest
        ))

        return tokenResp.value
    }
    
    static func signOutUser(signOutRequest: SignOutRequest) async throws {

        guard let appId = Context.currentContext.store.state.appConfig.id else {  throw RowndError("AppId not found") }
        
        try await Rownd.apiClient.send(Request(
            path: "/me/applications/\(appId)/signout",
            method: .post,
            body: signOutRequest
        ))
        
    }
}

extension JWT {
    var ntpExpired: Bool {
        guard let date = self.expiresAt else {
            return false
        }

        let ntpDate = NetworkTimeManager.shared.currentTime

        guard let ntpDate = ntpDate else {
            return self.expired
        }

        // Token is expired if the token expiration timestamp is less than the current timestamp (minus a 60 second buffer)

        return date.compare(ntpDate) != ComparisonResult.orderedDescending
    }
}
