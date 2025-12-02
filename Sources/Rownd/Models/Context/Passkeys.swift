//
//  Passkeys.swift
//  framework
//
//  Created by Matt Hamann on 7/8/22.
//

import AnyCodable
import Foundation
import Get
import UIKit

public struct PasskeyRegistration: Hashable, Sendable {
    public var id: String?
}

extension PasskeyRegistration: Codable {
    enum CodingKeys: String, CodingKey {
        case id
    }
}

public struct PasskeyState: Hashable, Sendable {
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

public struct PasskeysRegistrationResponse: Hashable, Sendable {
    public var passkeys: [PasskeyRegistration]
}

extension PasskeysRegistrationResponse: Codable {
    public enum CodingKeys: String, CodingKey {
        case passkeys
    }
}

class PasskeyData {
    static func fetchPasskeyRegistration() async {
        let state = Context.currentContext.store.state
        guard !state.passkeys.isLoading else { return }

        if Context.currentContext.store.state.appConfig.config?.hub?.auth?.signInMethods?.passkeys?.enabled != true {
            logger.debug("Passkeys are not enabled")
            return
        }

        guard state.auth.isAuthenticated else {
            return
        }

        await Context.currentContext.store.mutate { state in
            state.passkeys.isLoading = true
        }

        defer {
            Task {
                await Context.currentContext.store.mutate { state in
                    state.passkeys.isLoading = false
                }
            }
        }

        do {
            let response = try await Rownd.apiClient.send(Request<PasskeysRegistrationResponse>(path: "/me/auth/passkeys", method: .get)).value

            logger.debug("Passkey response: \(String(describing: response))")

            await Context.currentContext.store.mutate { state in
                state.passkeys.isInitialized = true
                state.passkeys.registration = response.passkeys
            }

        } catch {
            logger.error("Failed to retrieve passkeys: \(String(describing: error))")
        }
    }
}
