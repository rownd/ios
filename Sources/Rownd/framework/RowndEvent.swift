//
//  File.swift
//  
//
//  Created by Matt Hamann on 3/20/24.
//

import Foundation
import AnyCodable
import Combine

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
    public var event: RowndEventType
    public var data: [String: AnyCodable?]?
}

public protocol RowndEventHandlerDelegate: AnyObject {
    func handleRowndEvent(_ event: RowndEvent)
}

@MainActor
class RowndEventEmitter {
    static private var cancellables = Set<AnyCancellable>()
    static func emit(_ event: RowndEvent) {
        if event.event == .signInCompleted {
            let subscription = Context.currentContext.store.subscribe { $0.auth.isAccessTokenValid }
            subscription.$current.sink { isAccessTokenValid in
                if isAccessTokenValid {
                    subscription.unsubscribe()
                    Context.currentContext.eventListeners.forEach { listener in
                        listener.handleRowndEvent(event)
                    }
                }
            }.store(in: &Self.cancellables)
        } else {
            Context.currentContext.eventListeners.forEach { listener in
                listener.handleRowndEvent(event)
            }
        }
    }
}
