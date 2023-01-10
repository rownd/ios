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
import Kronos

extension Date {
    static func ISOStringFromDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        
        return dateFormatter.string(from: date).appending("Z")
    }
}

public enum SignInMethodTypes: String, Codable {
    case apple, google
}

public struct SignInState: Hashable, Codable {
    public var lastSignIn: SignInMethodTypes?
    public var lastSignInDate: String?
    
    func toSignInHash() -> String? {
        let signInInit = [
            "last_sign_in": store.state.signIn.lastSignIn?.rawValue,
            "last_sign_in_date": store.state.signIn.lastSignInDate
        ]

        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(signInInit)
            return encoded.base64EncodedString()
        } catch {
            logger.error("Failed to build login hash string: \(String(describing: error))")
            return nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case lastSignIn = "last_sign_in"
        case lastSignInDate = "last_sign_in_date"
    }
}


// MARK: Reducers
struct SetSignInMethod: Action {
    var payload: SignInMethodTypes
}

struct ResetSignInState: Action {}

func signInReducer(action: Action, state: SignInState?) -> SignInState {
    var state = state ?? SignInState()
    
    switch action {
    case let action as ResetSignInState:
        state = SignInState()
    case let action as SetSignInMethod:
        state.lastSignIn = action.payload
        state.lastSignInDate = Date.ISOStringFromDate(date: Clock.now ?? Date())
    default:
        break
    }
    
    return state
}


