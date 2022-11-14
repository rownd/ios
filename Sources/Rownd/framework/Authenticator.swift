//
//  Authenticator.swift
//  Rownd
//
//  Created by Matt Hamann on 10/16/22.
//

import Foundation
import Combine
import Get
import Factory
import ReSwift

enum AuthenticationError: Error {
    case noAccessTokenPresent
    case refreshTokenAlreadyConsumed
    case networkConnectionFailure
}

internal let tokenApiConfig = APIClient.Configuration(
    baseURL: URL(string: Rownd.config.apiUrl),
    delegate: TokenApiClientDelegate()
)

internal func tokenApiFactory() -> APIClient {
    return Get.APIClient(configuration: tokenApiConfig)
}

fileprivate class TokenApiClientDelegate : APIClientDelegate {
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        request.setValue(DEFAULT_API_USER_AGENT, forHTTPHeaderField: "User-Agent")
    }

    // Handle refresh token non-400 response codes
    func client(_ client: APIClient, shouldRetry task: URLSessionTask, error: Error, attempts: Int) async throws -> Bool {
        if
            case .unacceptableStatusCode(let statusCode) = error as? APIError,
            statusCode != 400,
            attempts <= 5 {
            return true
        }

        switch (error as? URLError)?.code {
        case
            .some(.timedOut),
            .some(.cannotFindHost),
            .some(.cannotConnectToHost),
            .some(.networkConnectionLost),
            .some(.dnsLookupFailed):
            if attempts <= 5 {
                return true
            }
        default: break
        }

        return false
    }
}

// This class exists for the sole purpose of subscribing the Authenticator to the
// global state. Data races can occur when using subscribers within the actor itself,
// which leads to memmory corruption and weird app crashes.
class AuthenticatorSubscription: NSObject {
    private static let inst: AuthenticatorSubscription = AuthenticatorSubscription()

    private override init() {}

    /// This checks the incoming action to determine whether it contains an AuthState payload and pushes that
    /// to the Authenticator if present. This prevents race conditions between the internal Rownd state and any
    /// external subscribers. The Authenticator MUST always reflect the correct state in order to prevent race conditions.
    internal static func createAuthenticatorMiddleware<State>() -> Middleware<State> {
        return { dispatch, getState in
            return { next in
                return { action in
                    var authState: AuthState?

                    switch(action) {
                    case let action as SetAuthState:
                        authState = action.payload
                    case let action as InitializeRowndState:
                        authState = action.payload.auth
                    default:
                        break
                    }

                    guard let authState = authState else {
                        return next(action)
                    }

                    Task {
                        logger.debug("Updating authenticator state...")
                        await Rownd.authenticator.setAuthState(authState)
                        logger.debug("Updating authenticator state...DONE")
                        next(action)
                    }
                }
            }
        }
    }
}

actor Authenticator {
    private let tokenApi = Container.tokenApi()
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
                let newAuthState: AuthState = try await tokenApi.send(
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

                switch (error as? URLError)?.code {
                case
                    .some(.notConnectedToInternet),
                    .some(.timedOut),
                    .some(.cannotFindHost),
                    .some(.cannotConnectToHost),
                    .some(.networkConnectionLost),
                    .some(.dnsLookupFailed):
                        throw AuthenticationError.networkConnectionFailure
                default: break
                }

                // Sign the user out b/c they need to get a new refresh token - this really should be abstracted out elsewhere
                Rownd.signOut()

                throw AuthenticationError.refreshTokenAlreadyConsumed
            }
        }

        self.refreshTask = task

        return try await task.value
    }
}
