//
//  StateStore.swift
//  Rownd
//
//  Public-facing state management API that wraps StateActor.
//  Provides multiple subscription mechanisms and handles persistence.
//

import AnyCodable
import Combine
import Foundation
import SwiftUI
import os

// MARK: - State Store

/// The main public interface for Rownd state management.
/// Provides synchronous state access, async mutations, and multiple subscription APIs.
public final class StateStore: @unchecked Sendable {
    // MARK: - Properties

    /// The underlying state actor.
    private let actor: StateActor

    /// Logger for state operations.
    private let log = Logger(subsystem: "io.rownd.sdk", category: "store")

    /// Storage key for persisted state.
    private let storageKey = "RowndState"

    /// Debouncer for save operations.
    private let saveDebouncer = Debouncer(delay: 0.1)

    /// Active subscription tokens for cleanup.
    private var subscriptionTokens: [SubscriptionToken] = []

    /// Lock for subscription token management.
    private let tokenLock = OSAllocatedUnfairLock()

    // MARK: - Combine Support

    /// Subject for broadcasting state changes to Combine subscribers.
    private let stateSubject = PassthroughSubject<RowndState, Never>()

    /// Current value subject for immediate access.
    private let currentStateSubject: CurrentValueSubject<RowndState, Never>

    // MARK: - Initialization

    public init(initialState: RowndState = RowndState()) {
        self.actor = StateActor(initialState: initialState)
        self.currentStateSubject = CurrentValueSubject(initialState)

        // Set up middleware for persistence and Combine broadcasting
        Task {
            await actor.addMiddleware { [weak self] oldState, newState in
                await self?.handleStateChange(oldState: oldState, newState: newState)
            }
        }
    }

    // MARK: - Synchronous State Access

    /// Get the current state synchronously from any thread.
    public var state: RowndState {
        actor.state
    }

    /// Subscript access to state slices.
    public subscript<T>(keyPath: KeyPath<RowndState, T>) -> T {
        actor.getState(keyPath)
    }

    // MARK: - State Mutation

    /// Update a specific state property.
    @discardableResult
    public func update<T>(_ keyPath: WritableKeyPath<RowndState, T>, value: T) async -> RowndState {
        await actor.update(keyPath, value: value)
    }

    /// Perform a complex state mutation.
    @discardableResult
    public func mutate(_ mutation: @escaping (inout RowndState) -> Void) async -> RowndState {
        await actor.mutate(mutation)
    }

    /// Replace the entire state (used for initialization/reload).
    @discardableResult
    public func replaceState(_ newState: RowndState) async -> RowndState {
        await actor.replaceState(newState)
    }

    // MARK: - AsyncStream Subscriptions

    /// Subscribe to changes in a specific state slice using AsyncStream.
    /// - Parameter keyPath: The key path to observe
    /// - Returns: An AsyncStream that emits values when the state slice changes
    public func stream<T: Sendable & Equatable>(
        _ keyPath: KeyPath<RowndState, T>
    ) async -> AsyncStream<T> {
        let (stream, token) = await actor.subscribe(to: keyPath)
        storeToken(token)
        return stream
    }

    /// Subscribe to the entire state using AsyncStream.
    public func streamAll() async -> AsyncStream<RowndState> {
        let (stream, token) = await actor.subscribeToAll()
        storeToken(token)
        return stream
    }

    // MARK: - Combine Subscriptions

    /// Get a Combine publisher for a specific state slice.
    /// - Parameter keyPath: The key path to observe
    /// - Returns: A publisher that emits values when the state slice changes
    public func publisher<T: Equatable>(
        for keyPath: KeyPath<RowndState, T>
    ) -> AnyPublisher<T, Never> {
        currentStateSubject
            .map(keyPath)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    /// Get a Combine publisher for the entire state.
    public func publisher() -> AnyPublisher<RowndState, Never> {
        currentStateSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Persistence

    /// Load state from persistent storage.
    @discardableResult
    public func load() async -> RowndState {
        guard let existingStateStr = Storage.shared.get(forKey: storageKey) else {
            await mutate { $0.isStateLoaded = true }
            return state
        }

        do {
            let decoder = JSONDecoder()
            var decoded = try decoder.decode(
                RowndState.self,
                from: existingStateStr.data(using: .utf8) ?? Data()
            )
            decoded.isStateLoaded = true
            decoded.clockSyncState =
                NetworkTimeManager.shared.currentTime != nil ? .synced : state.clockSyncState

            return await replaceState(decoded)
        } catch {
            log.debug("Failed decoding state from storage: \(String(describing: error))")
            await mutate { $0.isStateLoaded = true }
            return state
        }
    }

    /// Reload state from persistent storage if it has changed.
    public func reload() async {
        guard let existingStateStr = Storage.shared.get(forKey: storageKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(
                RowndState.self,
                from: existingStateStr.data(using: .utf8) ?? Data()
            )

            // Only reload if the timestamp is different
            if decoded.lastUpdateTs.timeIntervalSinceReferenceDate
                != state.lastUpdateTs.timeIntervalSinceReferenceDate
            {
                await mutate { state in
                    state = decoded
                    state.clockSyncState = self.state.clockSyncState
                    state.isStateLoaded = true
                }
            }
        } catch {
            log.debug(
                "Failed decoding state from storage during reload: \(String(describing: error))")
        }
    }

    /// Save state to persistent storage.
    private func save(_ state: RowndState) {
        saveDebouncer.debounce { [weak self, state] in
            guard let self = self else { return }
            if let encoded = try? state.toJson() {
                Storage.shared.set(encoded, forKey: self.storageKey)
                DarwinNotificationManager.shared.postNotification(
                    name: "io.rownd.events.StateUpdated")
                self.log.trace("Wrote state to storage")
            }
        }
    }

    // MARK: - Internal

    private func handleStateChange(oldState: RowndState, newState: RowndState) async {
        // Update Combine subjects
        await MainActor.run {
            currentStateSubject.send(newState)
            stateSubject.send(newState)
        }

        // Persist state (skip for certain state-only changes)
        if shouldPersist(oldState: oldState, newState: newState) {
            save(newState)
        }
    }

    private func shouldPersist(oldState: RowndState, newState: RowndState) -> Bool {
        // Don't persist if only clockSyncState or isStateLoaded changed
        var oldForComparison = oldState
        var newForComparison = newState
        oldForComparison.clockSyncState = .unknown
        newForComparison.clockSyncState = .unknown
        oldForComparison.isStateLoaded = false
        newForComparison.isStateLoaded = false
        oldForComparison.lastUpdateTs = Date.distantPast
        newForComparison.lastUpdateTs = Date.distantPast

        return oldForComparison != newForComparison
    }

    private func storeToken(_ token: SubscriptionToken) {
        tokenLock.withLock {
            subscriptionTokens.append(token)
            // Clean up cancelled tokens
            subscriptionTokens.removeAll { $0.isCancelled }
        }
    }

    /// Cancel all active subscriptions.
    public func cancelAllSubscriptions() {
        tokenLock.withLock {
            for token in subscriptionTokens {
                token.cancel()
            }
            subscriptionTokens.removeAll()
        }
    }

    deinit {
        cancelAllSubscriptions()
    }
}

// MARK: - Convenience Extensions

extension StateStore {
    // MARK: - Auth State

    /// Update the authentication state.
    public func setAuth(_ auth: AuthState) async {
        await update(\.auth, value: auth)
    }

    /// Clear authentication (sign out).
    public func clearAuth() async {
        await update(\.auth, value: AuthState())
    }

    // MARK: - User State

    /// Update the user state.
    public func setUser(_ user: UserState) async {
        await update(\.user, value: user)
    }

    /// Update user data.
    public func setUserData(_ data: [String: AnyCodable]) async {
        await mutate { state in
            state.user.data = data
            state.user.isLoading = false
        }
    }

    /// Set user loading state.
    public func setUserLoading(_ isLoading: Bool) async {
        await update(\.user.isLoading, value: isLoading)
    }

    // MARK: - App Config State

    /// Update the app configuration.
    public func setAppConfig(_ config: AppConfigState) async {
        await update(\.appConfig, value: config)
    }

    // MARK: - Clock Sync

    /// Update clock sync state.
    internal func setClockSync(_ clockSyncState: ClockSyncState) async {
        await update(\.clockSyncState, value: clockSyncState)
    }

    // MARK: - Passkeys

    /// Update passkey state.
    public func setPasskeys(_ passkeys: PasskeyState) async {
        await update(\.passkeys, value: passkeys)
    }

    // MARK: - Sign In

    /// Update sign in state.
    public func setSignIn(_ signIn: SignInState) async {
        await update(\.signIn, value: signIn)
    }

    /// Reset sign in state.
    public func resetSignIn() async {
        await update(\.signIn, value: SignInState())
    }
}

// MARK: - SwiftUI Support

extension StateStore {
    /// Create an observable state wrapper for SwiftUI.
    /// This returns an ObservableState that can be used with @StateObject.
    public func subscribe<T: Hashable>(
        _ selector: @escaping (RowndState) -> T
    ) -> LegacyObservableState<T> {
        LegacyObservableState(store: self, selector: selector)
    }

    /// Create a throttled observable state wrapper for SwiftUI.
    public func subscribeThrottled<T: Hashable>(
        _ selector: @escaping (RowndState) -> T,
        throttleInMs: Int = 350
    ) -> LegacyObservableThrottledState<T> {
        LegacyObservableThrottledState(store: self, selector: selector, throttleInMs: throttleInMs)
    }
}
