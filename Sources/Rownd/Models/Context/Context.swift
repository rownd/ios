//
//  Context.swift
//  framework
//
//  Created by Matt Hamann on 6/22/22.
//

import Foundation
import ReSwift

class Context {
    public internal(set) static var currentContext: Context = Context()

    let store: Store<RowndState>

    var eventListeners: [RowndEventHandlerDelegate] = []

    var authenticator: AuthenticatorProtocol = Authenticator()

    init() {
        store = createStore()
    }

    init(_ store: Store<RowndState>) {
        self.store = store
        Context.currentContext = self
    }
}
