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
}

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
