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
    public var passkeys = PasskeyState()
    public var signIn = SignInState()
    public var showActionOverlay = false
}

extension RowndState {
    enum CodingKeys: String, CodingKey {
        case appConfig, auth, user, signIn, passkeys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appConfig = try container.decode(AppConfigState.self, forKey: .appConfig)
        auth = try container.decode(AuthState.self, forKey: .auth)
        user = try container.decode(UserState.self, forKey: .user)
        passkeys = try container.decode(PasskeyState.self, forKey: .passkeys)
        signIn = try container.decodeIfPresent(SignInState.self, forKey: .signIn) ?? SignInState()
    }

    static func save(state: RowndState) {
        Task {
            if let encoded = try? state.toJson() {
                //            logger.trace("storing: \(encoded)")
                Storage.store?.set(encoded, forKey: STORAGE_STATE_KEY)
            }
        }
    }
    
    static func load() {
        let existingStateStr = Storage.store?.object(forKey: STORAGE_STATE_KEY) as? String ?? String("{}")
//        logger.trace("initial store state: \(existingStateStr)")
        
        do {
            let decoder = JSONDecoder()
            var decoded = try decoder.decode(
                RowndState.self,
                from: (existingStateStr.data(using: .utf8) ?? Data())
            )
            decoded.isInitialized = true
            DispatchQueue.main.async {
                store.dispatch(InitializeRowndState(payload: decoded))
            }
        } catch {
            logger.debug("Failed decoding state from storage (if this is the first time launching the app, this is expected): \(String(describing: error))")
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

struct ShowActionOverlay: Action {
    var payload: Bool
}

func rowndStateReducer(action: Action, state: RowndState?) -> RowndState {
    let state = state ?? RowndState()
    
    var newState: RowndState
    switch (action) {
    case let initializeAction as InitializeRowndState:
        newState = initializeAction.payload
    case let showActionOverlayAction as ShowActionOverlay:
        newState = state
        newState.showActionOverlay = showActionOverlayAction.payload
    default:
        newState = RowndState(
            isInitialized: true,
            appConfig: appConfigReducer(action: action, state: state.appConfig),
            auth: authReducer(action: action, state: state.auth),
            user: userReducer(action: action, state: state.user),
            passkeys: passkeyReducer(action: action, state: state.passkeys),
            signIn: signInReducer(action: action, state: state.signIn),
            showActionOverlay: false
        )

        RowndState.save(state: newState)
    }

    return newState
}

let thunkMiddleware: Middleware<RowndState> = createThunkMiddleware()
let authenticatorMiddleware: Middleware<RowndState> = AuthenticatorSubscription.createAuthenticatorMiddleware()

let store = Store(
    reducer: rowndStateReducer,
    state: RowndState(),
    middleware: [
        thunkMiddleware,
        authenticatorMiddleware
    ]
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
