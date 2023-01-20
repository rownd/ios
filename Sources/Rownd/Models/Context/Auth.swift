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
import Kronos

fileprivate let tokenQueue = DispatchQueue(label: "Rownd refresh token queue")

public struct AuthState: Hashable {
    public var isLoading: Bool = false
    public var accessToken: String?
    public var refreshToken: String?
    public var isVerifiedUser: Bool?
    public var hasPreviouslySignedIn: Bool? = false
}

extension AuthState: Codable {
    public var isAuthenticated: Bool {
        return accessToken != nil
    }

    public var isAccessTokenValid: Bool {
        guard let accessToken = accessToken else {
            return false
        }

        do {
            let jwt = try decode(jwt: accessToken)
            
            let currentDate = Clock.now ?? Date()
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
    }

    func toRphInitHash() -> String? {
        let userId: String? = store.state.user.get(field: "user_id") as? String ?? nil
        let rphInit = [
            "access_token": self.accessToken,
            "refresh_token": self.refreshToken,
            "app_id": store.state.appConfig.id,
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
    
    func getAccessToken() async throws -> String? {
        do {
            let authState = try await Rownd.authenticator.getValidToken()
            return authState.accessToken
        } catch {
            logger.warning("Failed to retrieve access token: \(String(describing: error))")

            switch (error as? AuthenticationError) {
            case .networkConnectionFailure:
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
    default:
        break
    }

    if (hasPreviouslySignedIn ?? false || state.isAuthenticated) {
        state.hasPreviouslySignedIn = true
    }
    
    return state
}

// MARK: Token / auth API calls

public enum UserType: String, Codable {
    case NewUser = "new_user"
    case ExistingUser = "existing_user"
}

struct TokenRequest: Codable {
    var refreshToken: String?
    var idToken: String?
    var appId: String?
    var intent: RowndSignInIntent?
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case appId = "app_id"
        case intent
    }
}

struct TokenResponse: Codable {
    var refreshToken: String?
    var accessToken: String?
    var userType: UserType?
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case accessToken = "access_token"
        case userType = "user_type"
    }
}


struct TokenResource: APIResource {
    
    var headers: Dictionary<String, String>?
    
    typealias ModelType = TokenResponse
    
    var methodPath: String {
        return "/hub/auth/token"
    }
}



class Auth {
    
    static func fetchToken(idToken: String, intent: RowndSignInIntent?, withCompletion completion: @escaping (TokenResponse?) -> Void) -> Void {
        guard let appId = store.state.appConfig.id else { return completion(nil) }
        let tokenRequest = TokenRequest(idToken: idToken, appId: appId, intent: intent)
        return fetchToken(tokenRequest: tokenRequest, withCompletion: completion)
    }
    
    static func fetchToken(tokenRequest: TokenRequest, withCompletion completion: @escaping (TokenResponse?) -> Void) -> Void {
        var resource = TokenResource()
        resource.headers = [
            "Content-Type": "application/json"
        ]

        let request = APIRequest(resource: resource)

        let encoder = JSONEncoder()
        var body: Data?
        
        do {
            body = try encoder.encode(tokenRequest)
        } catch {
            return completion(nil)
        }
        
        request.execute(method: "POST", body: body) { tokenResp in
            // This guard ensures that the resource allocator doesn't clean up the request object before
            // the parsing closure in request.execute() is finished with it.
            guard request.decode != nil else { return }
            // Only enable this when debugging API responses, since it could log sensitive info
            //            logger.trace("Received tokens: \(String(describing: tokenResp))")
            
            completion(tokenResp)
        }
    }
}

extension JWT {
    var ntpExpired: Bool {
        guard let date = self.expiresAt else {
            return false
        }

        let ntpDate = Clock.now

        guard let ntpDate = ntpDate else {
            return self.expired
        }

        return date.compare(ntpDate) != ComparisonResult.orderedDescending
    }
}
