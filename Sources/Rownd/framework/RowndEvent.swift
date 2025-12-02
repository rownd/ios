//
//  RowndEvent.swift
//
//
//  Created by Matt Hamann on 3/20/24.
//

import AnyCodable
import Combine
import Foundation

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

class RowndEventEmitter {
    static private var cancellables = Set<AnyCancellable>()

    static func emit(_ event: RowndEvent) {
        if event.event == .signInCompleted {
            // Wait for access token to be valid before emitting sign-in completed
            Context.currentContext.store.publisher(for: \.auth.isAccessTokenValid)
                .filter { $0 }
                .first()
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    Context.currentContext.eventListeners.forEach { listener in
                        listener.handleRowndEvent(event)
                    }
                }
                .store(in: &Self.cancellables)
        } else {
            Context.currentContext.eventListeners.forEach { listener in
                listener.handleRowndEvent(event)
            }
        }
    }
}
