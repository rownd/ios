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
}

extension AuthState: Codable {
    public var isAuthenticated: Bool {
        return accessToken != nil
    }
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case isVerifiedUser = "is_verified_user"
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
                        Auth.refreshToken(refreshToken: refreshToken) { tokenResource in
                            if let newAuthState = tokenResource {
                                store.dispatch(SetAuthState(payload: newAuthState))
                                continuation.resume(returning: newAuthState.accessToken)
                            } else {
                                // Sign the user out b/c they need to get a new refresh token
                                store.dispatch(SetAuthState(payload: AuthState()))
                                store.dispatch(SetUserData(payload: [:]))
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
    default:
        break
    }
    
    return state
}

// MARK: Token / auth API calls

struct TokenRequest: Codable {
    var refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
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
    static func refreshToken(refreshToken: String, withCompletion completion: @escaping (AuthState?) -> Void) -> Void {
        var resource = TokenResource()
        let request = APIRequest(resource: resource)
        
        resource.headers = [
            "Content-Type": "application/json"
        ]
        
        let encoder = JSONEncoder()
        var body: Data?
        do {
            body = try encoder.encode(TokenRequest(refreshToken: refreshToken))
        } catch {
            return completion(nil)
        }
        
        request.execute(method: "POST", body: body) { tokenResp in
            // This guard ensures that the resource allocator doesn't clean up the request object before
            // the parsing closure in request.execute() is finished with it.
            guard request.decode != nil else { return }
            logger.trace("Received tokens: \(String(describing: tokenResp))")
            
            completion(tokenResp)
        }
    }
}
