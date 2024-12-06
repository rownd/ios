//
//  Auth.swift
//  framework
//
//  Created by Matt Hamann on 7/8/22.
//

import Foundation
import UIKit
import ReSwift
import ReSwiftThunk
import AnyCodable
import Get

public struct PasskeyRegistration: Hashable {
    public var id: String?
}

extension PasskeyRegistration: Codable {
    enum CodingKeys: String, CodingKey {
        case id
    }
}

public struct PasskeyState: Hashable {
    public var isLoading: Bool = false
    public var isInitialized: Bool = false
    public var isErrored: Bool = false
    public var errorMessage: String?
    public var registration: [PasskeyRegistration]? = []
}

extension PasskeyState: Codable {
    public enum CodingKeys: String, CodingKey {
        case registration
    }

    public func get() -> PasskeyState {
        return self
    }
}

struct SetPasskeyState: Action {
    public var payload = PasskeyState()
}

struct SetPasskeyLoading: Action {
    var isLoading: Bool
}

struct SetPasskeyInitialized: Action {
    var isInitialized: Bool
}

struct SetPasskeyRegistration: Action {
    var payload: [PasskeyRegistration]
}

struct SetPasskeyError: Action {
    var isErrored: Bool = true
    var errorMessage: String
}

func passkeyReducer(action: Action, state: PasskeyState?) -> PasskeyState {
    var state = state ?? PasskeyState()

    switch action {
    case let action as SetPasskeyState:
        state = action.payload
    case let action as SetPasskeyLoading:
        state.isLoading = action.isLoading
    case let action as SetPasskeyInitialized:
        state.isInitialized = action.isInitialized
    case let action as SetPasskeyRegistration:
        state.isInitialized = true
        state.registration = action.payload
    case let action as SetAuthState:
        if !action.payload.isAuthenticated {
            state = PasskeyState()
        }
    default:
        break
    }

    return state
}

public struct PasskeysRegistrationResponse: Hashable {
    public var passkeys: [PasskeyRegistration]
}

extension PasskeysRegistrationResponse: Codable {
    public enum CodingKeys: String, CodingKey {
        case passkeys
    }
}

class PasskeyData {
    static func fetchPasskeyRegistration() -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard !state.passkeys.isLoading else { return }

            if Context.currentContext.store.state.appConfig.config?.hub?.auth?.signInMethods?.passkeys?.enabled != true {
                logger.debug("Passkeys are not enabled")
                return
            }

            Task {
                guard state.auth.isAuthenticated else {
                    return
                }

                DispatchQueue.main.async {
                    dispatch(SetPasskeyLoading(isLoading: true))
                }

                defer {
                    DispatchQueue.main.async {
                        dispatch(SetPasskeyLoading(isLoading: false))
                    }
                }

                do {
                    let response = try await Rownd.apiClient.send(Request<PasskeysRegistrationResponse>(path: "/me/auth/passkeys", method: .get)).value

                    logger.debug("Passkey response: \(String(describing: response))")

                    DispatchQueue.main.async {
                        dispatch(SetPasskeyRegistration(payload: response.passkeys))
                    }

                } catch {
                    logger.error("Failed to retrieve passkeys: \(String(describing: error))")
                }
            }
        }
    }
}
