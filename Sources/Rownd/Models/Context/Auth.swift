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

fileprivate let tokenQueue = DispatchQueue(label: "Rownd refresh token queue")

public struct AuthState: Hashable {
    public var isLoading: Bool = false
    public var accessToken: String?
    public var refreshToken: String?
    public var isVerifiedUser: Bool?
    public var hasPreviouslySignedIn: Bool?
}

extension AuthState: Codable {
    public var isAuthenticated: Bool {
        return accessToken != nil
    }
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case isVerifiedUser = "is_verified_user"
        case hasPreviouslySignedIn = "has_Previously_Signed_In"
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
    
    func getAccessToken() async -> String? {
        guard let accessToken = store.state.auth.accessToken else { return nil }
        
        return await withCheckedContinuation { continuation in
            tokenQueue.async {
                do {
                    let jwt = try decode(jwt: accessToken)
                    
                    if !jwt.expired {
                        continuation.resume(returning: accessToken)
                        return
                    }
                    
                    if let refreshToken = store.state.auth.refreshToken {
                        Auth.fetchToken(refreshToken: refreshToken) { tokenResource in
                            if let newAuthState = tokenResource {
                                DispatchQueue.main.async {
                                    store.dispatch(SetAuthState(payload: newAuthState))
                                }
                                continuation.resume(returning: newAuthState.accessToken)
                            } else {
                                // Sign the user out b/c they need to get a new refresh token
                                DispatchQueue.main.async {
                                    store.dispatch(SetAuthState(payload: AuthState()))
                                    store.dispatch(SetUserData(payload: [:]))
                                }
                                continuation.resume(returning: nil)
                            }
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                    
                } catch {
                    continuation.resume(returning: nil)
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
    
    switch action {
    case let action as SetAuthState:
        state = action.payload
        if (state.hasPreviouslySignedIn ?? false || state.isAuthenticated) {
            state.hasPreviouslySignedIn = true
        }
    default:
        break
    }
    
    return state
}

func receiveAuthTokens() -> Thunk<RowndState> {
    return Thunk<RowndState> { dispatch, getState in
        guard let state = getState() else { return }

        DispatchQueue.main.async {
            store.dispatch(UserData.fetch())
        }

    }
}

// MARK: Token / auth API calls

struct TokenRequest: Codable {
    var refreshToken: String?
    var idToken: String?
    var appId: String?
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case appId = "app_id"
    }
}

struct TokenResource: APIResource {
    var headers: Dictionary<String, String>?
    
    typealias ModelType = AuthState
    
    var methodPath: String {
        return "/hub/auth/token"
    }
}

class Auth {
    static func fetchToken(refreshToken: String, withCompletion completion: @escaping (AuthState?) -> Void) -> Void {
        let tokenRequest = TokenRequest(refreshToken: refreshToken)
        return fetchToken(tokenRequest: tokenRequest, withCompletion: completion)
    }
    
    static func fetchToken(idToken: String, withCompletion completion: @escaping (AuthState?) -> Void) -> Void {
        guard let appId = store.state.appConfig.id else { return completion(nil) }
        let tokenRequest = TokenRequest(idToken: idToken, appId: appId)
        return fetchToken(tokenRequest: tokenRequest, withCompletion: completion)
    }
    
    static func fetchToken(tokenRequest: TokenRequest, withCompletion completion: @escaping (AuthState?) -> Void) -> Void {
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
