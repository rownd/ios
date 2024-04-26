//
//  RowndState.swift
//
//
//  Created by Matt Hamann on 4/3/24.
//

import Foundation
import ReSwift
import ReSwiftThunk
import Kronos

fileprivate let STORAGE_STATE_KEY = "RowndState"

let debouncer = Debouncer(delay: 0.1) // 100ms

public struct RowndState: Codable, Hashable {
    public var isStateLoaded = false
    internal var clockSyncState: ClockSyncState = Clock.now != nil ? .synced : .waiting
    public var appConfig = AppConfigState()
    public var auth = AuthState()
    public var user = UserState()
    public var passkeys = PasskeyState()
    public var signIn = SignInState()
}

extension RowndState {
    enum CodingKeys: String, CodingKey {
        case appConfig, auth, user, signIn, passkeys
    }
    
    public var isInitialized: Bool {
        return isStateLoaded && clockSyncState != .waiting
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appConfig = try container.decode(AppConfigState.self, forKey: .appConfig)
        auth = try container.decode(AuthState.self, forKey: .auth)
        user = try container.decode(UserState.self, forKey: .user)
        passkeys = try container.decodeIfPresent(PasskeyState.self, forKey: .passkeys) ?? PasskeyState()
        signIn = try container.decodeIfPresent(SignInState.self, forKey: .signIn) ?? SignInState()
    }

    internal func save() {
        debouncer.debounce(action: {
            if let encoded = try? self.toJson() {
                Storage.set(encoded, forKey: STORAGE_STATE_KEY)
            }
        })
    }
    
    public func load() async {
        await load(Context.currentContext.store)
    }
    
    internal func load(_ store: Store<RowndState>) async {
        let existingStateStr = Storage.get(forKey: STORAGE_STATE_KEY)
//        logger.trace("initial store state: \(existingStateStr)")
        
        guard let existingStateStr = existingStateStr else {
            await MainActor.run {
                store.dispatch(SetStateLoaded())
            }
            return
        }
        
        do {
            let decoder = JSONDecoder()
            var decoded = try decoder.decode(
                RowndState.self,
                from: (existingStateStr.data(using: .utf8) ?? Data())
            )
            decoded.isStateLoaded = true
            decoded.clockSyncState = Clock.now != nil ? .synced : store.state.clockSyncState
            await MainActor.run { [decoded] in
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

struct SetStateLoaded: Action {}

struct InitializeRowndState: Action {
    var payload: RowndState
}

struct SetClockSync: Action {
    var clockSyncState: ClockSyncState
}

func rowndStateReducer(action: Action, state: RowndState?) -> RowndState {
    var newState: RowndState
    switch (action) {
    case _ as SetStateLoaded:
        newState = state ?? Context.currentContext.store.state
        newState.isStateLoaded = true
    case let initializeAction as InitializeRowndState:
        newState = initializeAction.payload
        newState.clockSyncState = state?.clockSyncState ?? Context.currentContext.store.state.clockSyncState
    case let clockSyncAction as SetClockSync:
        newState = state ?? Context.currentContext.store.state
        newState.clockSyncState = clockSyncAction.clockSyncState
    default:
        newState = RowndState(
            isStateLoaded: true,
            clockSyncState: state?.clockSyncState ?? Context.currentContext.store.state.clockSyncState,
            appConfig: appConfigReducer(action: action, state: state?.appConfig),
            auth: authReducer(action: action, state: state?.auth),
            user: userReducer(action: action, state: state?.user),
            passkeys: passkeyReducer(action: action, state: state?.passkeys),
            signIn: signInReducer(action: action, state: state?.signIn)
        )

        newState.save()
    }

    return newState
}

func createStore() -> Store<RowndState> {
    return Store(
        reducer: rowndStateReducer,
        state: RowndState(),
        middleware: [
            thunkMiddleware,
            authenticatorMiddleware
        ]
    )
}

let thunkMiddleware: Middleware<RowndState> = createThunkMiddleware()
let authenticatorMiddleware: Middleware<RowndState> = AuthenticatorSubscription.createAuthenticatorMiddleware()

struct StateError: Error, CustomStringConvertible {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}
