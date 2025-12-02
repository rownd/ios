//
//  SignIn.swift
//  framework
//
//  Created by Matt Hamann on 6/25/22.
//

import Foundation
import UIKit

extension Date {
    static func ISOStringFromDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"

        return dateFormatter.string(from: date).appending("Z")
    }
}

public enum SignInMethodTypes: String, Codable, Sendable {
    case apple, google
}

public struct SignInState: Hashable, Codable, Sendable {
    public var lastSignIn: SignInMethodTypes?
    public var lastSignInDate: String?

    func toSignInHash() -> String? {
        let signInInit = [
            "last_sign_in": Context.currentContext.store.state.signIn.lastSignIn?.rawValue,
            "last_sign_in_date": Context.currentContext.store.state.signIn.lastSignInDate
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

// MARK: - Sign In Actions

extension StateStore {
    /// Set the last sign in method.
    func setLastSignInMethod(_ method: SignInMethodTypes) async {
        await mutate { state in
            state.signIn.lastSignIn = method
            state.signIn.lastSignInDate = Date.ISOStringFromDate(date: NetworkTimeManager.shared.currentTime ?? Date())
        }
    }
}
