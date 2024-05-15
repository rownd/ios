//
//  File.swift
//  
//
//  Created by Matt Hamann on 3/20/24.
//

import Foundation
import AnyCodable

public enum RowndEventType: String, Codable {
    case signInStarted = "sign_in_started"
    case signInCompleted = "sign_in_completed"
    case signInFailed = "sign_in_failed"
    case userUpdated = "user_updated"
    case signOut = "sign_out"
    case user_data = "user_data"
    case user_data_saved = "user_data_saved"
    case verificationStarted = "verification_started"
    case verificationCompleted = "verification_completed"
}

public struct RowndEvent: Codable {
    var event: RowndEventType
    var data: [String: AnyCodable?]?
}

public protocol RowndEventHandlerDelegate {
    func handleRowndEvent(_ event: RowndEvent)
}

class RowndEventEmitter {
    static func emit(_ event: RowndEvent) {
        guard let delegate = Rownd.config.eventDelegate else {
            return
        }

        delegate.handleRowndEvent(event)
    }
}
