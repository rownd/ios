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
    public var isInitialized = false
    public var appConfig = AppConfigState()
    public var auth = AuthState()
    public var user = UserState()
}

extension RowndState {
    enum CodingKeys: String, CodingKey {
        case appConfig, auth, user
    }

    static func save(state: RowndState) {
        if let encoded = try? state.toJson() {
//            logger.trace("storing: \(encoded)")
            Storage.store?.set(encoded, forKey: STORAGE_STATE_KEY)
        }
    }
    
    static func load() {
        let existingStateStr = Storage.store?.object(forKey: STORAGE_STATE_KEY) as? String ?? String("{}")
        logger.trace("initial store state: \(existingStateStr)")
        
        let decoder = JSONDecoder()
        if var decoded = try? decoder.decode(RowndState.self, from: (existingStateStr.data(using: .utf8) ?? Data())) {
            decoded.isInitialized = true
            DispatchQueue.main.async {
                store.dispatch(InitializeRowndState(payload: decoded))
            }
        }
    }

    public func toJson() throws -> String? {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            return String(data: encoded, encoding: .utf8)
        }

        throw StateError("Failed to encode state")
    }

    public func toDictionary() throws -> [String:Any?] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
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
            isInitialized: true,
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

struct StateError: Error, CustomStringConvertible {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}
