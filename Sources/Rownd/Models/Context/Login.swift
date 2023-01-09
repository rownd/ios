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

public enum LoginMethods: String, Codable {
    case apple, google
}

public struct LoginState: Hashable, Codable {
    public var lastLogin: LoginMethods?
    public var lastLoginDate: String?
    
    func toLoginHash() -> String? {
        let loginInit = [
            "last_login": store.state.login.lastLogin?.rawValue,
            "last_login_date": store.state.login.lastLoginDate
        ]

        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(loginInit)
            return encoded.base64EncodedString()
        } catch {
            logger.error("Failed to build login hash string: \(String(describing: error))")
            return nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case lastLogin = "last_login"
        case lastLoginDate = "last_login_date"
    }
}


// MARK: Reducers
struct SetLoginMethod: Action {
    var payload: LoginMethods
}

struct ResetLoginState: Action {}

func loginReducer(action: Action, state: LoginState?) -> LoginState {
    var state = state ?? LoginState()
    
    switch action {
    case let action as ResetLoginState:
        state = LoginState()
    case let action as SetLoginMethod:
        state.lastLogin = action.payload
        state.lastLoginDate = Date.ISOStringFromDate(date: Clock.now ?? Date())
    default:
        break
    }
    
    return state
}


