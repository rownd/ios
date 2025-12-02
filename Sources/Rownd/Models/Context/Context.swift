//
//  Context.swift
//  framework
//
//  Created by Matt Hamann on 6/22/22.
//

import Foundation

class Context {
    public internal(set) static var currentContext: Context = Context()

    /// The state store - replaces the old ReSwift Store.
    let store: StateStore

    var eventListeners: [RowndEventHandlerDelegate] = []

    var authenticator: AuthenticatorProtocol = Authenticator()

    init() {
        store = StateStore()
    }

    init(_ store: StateStore) {
        self.store = store
        Context.currentContext = self
    }
}

// MARK: - Test Helpers

/// Creates a new StateStore for testing purposes.
func createStore() -> StateStore {
    return StateStore()
}
