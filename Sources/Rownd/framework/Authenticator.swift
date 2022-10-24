//
//  Authenticator.swift
//  Rownd
//
//  Created by Matt Hamann on 10/16/22.
//

import Foundation
import Combine
import Get

enum AuthenticationError: Error {
    case noAccessTokenPresent
    case refreshTokenFailed
}

// This class exists for the sole purpose of subscribing the Authenticator to the
// global state. Data races can occur when using subscribers within the actor itself,
// which leads to memmory corruption and weird app crashes.
class AuthenticatorSubscription: NSObject {
    private static let inst: AuthenticatorSubscription = AuthenticatorSubscription()
    private var stateListeners = Set<AnyCancellable>()

    @Published private var authState: ObservableState<AuthState> = store.subscribe { $0.auth }

    private override init() {}

    internal static func subscribeToAuthState() {
        inst.authState
            .$current
            .sink { authState in
                Task {
                    await Rownd.authenticator.setAuthState(authState)
                }
            }
            .store(in: &inst.stateListeners)
    }
}

actor Authenticator {
    private var currentAuthState: AuthState? = store.state.auth
    private var refreshTask: Task<AuthState, Error>?

    func setAuthState(_ newAuthState: AuthState) {
        currentAuthState = newAuthState
    }

    func getValidToken() async throws -> AuthState {
        if let handle = refreshTask {
            return try await handle.value
        }

        guard let authState = currentAuthState, let _ = authState.accessToken else {
            throw AuthenticationError.noAccessTokenPresent
        }

        if authState.isAccessTokenValid {
            return authState
        }

        return try await refreshToken()
    }

    func refreshToken() async throws -> AuthState {
        if let refreshTask = refreshTask {
            return try await refreshTask.value
        }

        let task = Task { () throws -> AuthState in
            defer { refreshTask = nil }

            do {
                let newAuthState: AuthState = try await rowndApi.send(
                    Request(
                        path: "/hub/auth/token",
                        method: .post,
                        body: TokenRequest(refreshToken: currentAuthState?.refreshToken)
                    )
                ).value

                // Store the new token response here for immediate use outside of the state lifecycle
                currentAuthState = newAuthState

                // Update the auth state - this really should be abstracted out elsewhere
                DispatchQueue.main.async {
                    store.dispatch(SetAuthState(payload: AuthState(
                        accessToken: newAuthState.accessToken,
                        refreshToken: newAuthState.refreshToken,
                        isVerifiedUser: store.state.auth.isVerifiedUser,
                        hasPreviouslySignedIn: store.state.auth.hasPreviouslySignedIn
                    )))
                }

                return newAuthState
            } catch {
                logger.error("Token refresh failed: \(String(describing: error))")

                // Sign the user out b/c they need to get a new refresh token - this really should be abstracted out elsewhere
                DispatchQueue.main.async {
                    store.dispatch(SetAuthState(payload: AuthState()))
                    store.dispatch(SetUserData(payload: [:]))
                }

                throw AuthenticationError.refreshTokenFailed
            }
        }

        self.refreshTask = task

        return try await task.value
    }
}
