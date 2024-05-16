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
    case userData = "user_data"
    case userDataSaved = "user_data_saved"
    case verificationStarted = "verification_started"
    case verificationCompleted = "verification_completed"
}

public struct RowndEvent: Codable {
    var event: RowndEventType
    var data: [String: AnyCodable?]?
}

public protocol RowndEventHandlerDelegate: AnyObject {
    func handleRowndEvent(_ event: RowndEvent)
}

class RowndEventEmitter {
    static func emit(_ event: RowndEvent) {
        Context.currentContext.eventListeners.forEach { listener in
            listener.handleRowndEvent(event)
        }
    }
}
