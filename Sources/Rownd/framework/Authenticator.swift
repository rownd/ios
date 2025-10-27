//
//  Authenticator.swift
//  Rownd
//
//  Created by Matt Hamann on 10/16/22.
//

import Combine
import Factory
import Foundation
import Get
import OSLog
import ReSwift

private let log = Logger(subsystem: "io.rownd.sdk", category: "authenticator")

protocol AuthenticatorProtocol {
    func getValidToken() async throws -> AuthState
    func refreshToken() async throws -> AuthState
}

public enum AuthenticationError: Error, LocalizedError, Equatable {
    case noAccessTokenPresent
    case invalidRefreshToken(details: String)
    case networkConnectionFailure(details: String)
    case serverError(details: String)

    public var errorDescription: String? {
        switch self {
        case .noAccessTokenPresent:
            return "No access token present"
        case .invalidRefreshToken(let details):
            return "Invalid refresh token: \(details)"
        case .networkConnectionFailure(let details):
            return "Network connection failure: \(details)"
        case .serverError(let details):
            return "Server error: \(details)"
        }
    }
}

internal let tokenApiConfig = APIClient.Configuration(
    baseURL: URL(string: Rownd.config.apiUrl),
    delegate: TokenApiClientDelegate()
)

internal func tokenApiFactory() -> APIClient {
    return Get.APIClient(configuration: tokenApiConfig)
}

private class TokenApiClientDelegate: APIClientDelegate {
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        request.setValue(
            Constants.TIME_META_HEADER, forHTTPHeaderField: Constants.TIME_META_HEADER_NAME)
        request.setValue(Constants.DEFAULT_API_USER_AGENT, forHTTPHeaderField: "User-Agent")

        let localRequest = request
        log.info(
            "Making request to: \(String(describing: localRequest.httpMethod?.uppercased())) \(String(describing: localRequest.url))"
        )
    }

    // Handle refresh token non-400 response codes
    func client(_ client: APIClient, shouldRetry task: URLSessionTask, error: Error, attempts: Int)
        async throws -> Bool
    {
        if case .unacceptableStatusCode(let statusCode) = error as? APIError,
            statusCode != 400,
            attempts <= 5
        {
            return true
        }

        switch (error as? URLError)?.code {
        case .some(.timedOut),
            .some(.cannotFindHost),
            .some(.cannotConnectToHost),
            .some(.networkConnectionLost),
            .some(.notConnectedToInternet),
            .some(.cancelled),
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
    internal static var currentAuthState: AuthState? = Context.currentContext.store.state.auth

    private override init() {}

    /// This checks the incoming action to determine whether it contains an AuthState payload and pushes that
    /// to the Authenticator if present. This prevents race conditions between the internal Rownd state and any
    /// external subscribers. The Authenticator MUST always reflect the correct state in order to prevent race conditions.
    internal static func createAuthenticatorMiddleware<State>() -> Middleware<State> {
        return { _, _ in
            return { next in
                return { action in
                    var authState: AuthState?

                    switch action {
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
                    AuthenticatorSubscription.currentAuthState = authState
                    next(action)
                }
            }
        }
    }
}

actor Authenticator: AuthenticatorProtocol {
    private let tokenApi = Container.tokenApi()
    private var refreshTask: Task<AuthState, Error>?
    private var cancellables = Set<AnyCancellable>()

    private func storeCancellable(_ cancellable: AnyCancellable) {
        self.cancellables.insert(cancellable)
    }

    func getValidToken() async throws -> AuthState {
        if let handle = refreshTask {
            return try await handle.value
        }

        guard let authState = AuthenticatorSubscription.currentAuthState,
            authState.accessToken != nil
        else {
            throw AuthenticationError.noAccessTokenPresent
        }

        if authState.isAccessTokenValid {
            return authState
        }

        // authState.isAccessTokenValid could return false if state.clockSyncState is .waiting
        // even when the access token is valid. We should wait for the clock sync to complete
        // before proceeding with a token exchange.
        if Context.currentContext.store.state.clockSyncState == .waiting {
            do {
                try await waitForClockSync()
            } catch {
                log.error(
                    "Error encountered while waiting for clock sync \(String(describing: error))")
            }
            return try await getValidToken()
        }

        return try await refreshToken()
    }

    func refreshToken() async throws -> AuthState {
        if let refreshTask = refreshTask {
            log.debug("Waiting for token refresh already in progress")
            return try await refreshTask.value
        }

        let task = Task { () throws -> AuthState in
            defer { refreshTask = nil }

            do {
                log.debug("Refreshing auth tokens...")
                let newAuthState: AuthState = try await tokenApi.send(
                    Request(
                        path: "/hub/auth/token",
                        method: .post,
                        body: TokenRequest(
                            refreshToken: AuthenticatorSubscription.currentAuthState?.refreshToken)
                    )
                ).value

                log.debug("Successfully refreshed auth tokens.")

                // Store the new token response here for immediate use outside of the state lifecycle
                AuthenticatorSubscription.currentAuthState = newAuthState

                // Update the auth state - this really should be abstracted out elsewhere
                DispatchQueue.main.async {
                    Context.currentContext.store.dispatch(
                        SetAuthState(
                            payload: AuthState(
                                accessToken: newAuthState.accessToken,
                                refreshToken: newAuthState.refreshToken,
                                isVerifiedUser: Context.currentContext.store.state.auth
                                    .isVerifiedUser,
                                hasPreviouslySignedIn: Context.currentContext.store.state.auth
                                    .hasPreviouslySignedIn
                            )))
                }

                return newAuthState
            } catch {
                log.error("Token refresh failed: \(String(describing: error))")

                if case .unacceptableStatusCode(let statusCode) = error as? APIError,
                    statusCode != 400
                {
                    throw AuthenticationError.serverError(details: "\(String(describing: error))")
                }

                switch (error as? URLError)?.code {
                case .some(.notConnectedToInternet),
                    .some(.timedOut),
                    .some(.cannotFindHost),
                    .some(.cannotConnectToHost),
                    .some(.networkConnectionLost),
                    .some(.dnsLookupFailed):
                    throw
                        AuthenticationError
                        .networkConnectionFailure(
                            details: "\(String(describing: error))"
                        )
                default: break
                }

                // Sign the user out b/c they need to get a new refresh token - this really should be abstracted out elsewhere
                Rownd.signOut()

                throw
                    AuthenticationError
                    .invalidRefreshToken(details: (String(describing: error)))
            }
        }

        self.refreshTask = task

        return try await task.value
    }

    private func waitForClockSync() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Task 1: Wait for the clock sync
            group.addTask { @MainActor [weak self] in
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    var didResume = false
                    let subscriber = Context.currentContext.store.subscribe { $0.clockSyncState }

                    let cancellable = subscriber.$current.sink { clockSyncState in
                        if clockSyncState != .waiting && !didResume {
                            didResume = true
                            subscriber.unsubscribe()
                            continuation.resume()
                        }
                    }

                    Task { [weak self] in
                        await self?.storeCancellable(cancellable)
                    }
                }
            }

            // Task 2: Timeout after half a second
            group.addTask {
                try await Task.sleep(nanoseconds: 500_000_000)
                log.warning("Authenticator timed out waiting for clock sync. Proceeding...")
            }

            try await group.next()
            group.cancelAll()
        }
    }
}
