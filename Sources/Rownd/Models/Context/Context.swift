//
//  Context.swift
//  framework
//
//  Created by Matt Hamann on 6/22/22.
//

import Foundation
import ReSwift
import ReSwiftThunk

fileprivate let STORAGE_STATE_KEY = "RowndState"

public struct RowndState: Codable, Hashable {
    public var appConfig = AppConfigState()
    public var auth = AuthState()
    public var user = UserState()
}

extension RowndState {
    static func save(state: RowndState) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(state) {
            logger.trace("storing: \(String(data: encoded, encoding: .utf8) ?? "{}")")
            Storage.store?.set(String(data: encoded, encoding: .utf8), forKey: STORAGE_STATE_KEY)
        }
    }
    
    static func load() {
        let existingStateStr = Storage.store?.object(forKey: STORAGE_STATE_KEY) as? String ?? String("{}")
        logger.trace("initial store state: \(existingStateStr)")
        
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(RowndState.self, from: (existingStateStr.data(using: .utf8) ?? Data())) {
            store.dispatch(InitializeRowndState(payload: decoded))
        }
    }
}

struct InitializeRowndState: Action {
    var payload: RowndState
}

func rowndStateReducer(action: Action, state: RowndState?) -> RowndState {
    var newState: RowndState
    switch (action) {
    case let initializeAction as InitializeRowndState:
        newState = initializeAction.payload
    default:
        newState = RowndState(
            appConfig: appConfigReducer(action: action, state: state?.appConfig),
            auth: authReducer(action: action, state: state?.auth),
            user: userReducer(action: action, state: state?.user)
        )
        
        RowndState.save(state: newState)
    }
    
    return newState
}

let thunkMiddleware: Middleware<RowndState> = createThunkMiddleware()

let store = Store(
    reducer: rowndStateReducer,
    state: RowndState(),
    middleware: [thunkMiddleware]
)
