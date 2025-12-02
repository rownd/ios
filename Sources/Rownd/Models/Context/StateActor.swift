//
//  StateActor.swift
//  Rownd
//
//  Core actor-based state container providing thread-safe state management.
//  Uses a lock for synchronous reads and actor isolation for mutations.
//

import Foundation
import os

// MARK: - State Lock

/// A thread-safe lock wrapper for synchronous state access.
/// Uses os_unfair_lock for high-performance, low-level locking.
final class StateLock<Value>: @unchecked Sendable {
    private var _value: Value
    private let lock = OSAllocatedUnfairLock()

    init(_ value: Value) {
        self._value = value
    }

    /// Read the current value synchronously and thread-safely.
    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    /// Update the value synchronously and thread-safely.
    func withLock<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&_value)
    }
}

// MARK: - State Change

/// Represents a state change with old and new values.
public struct StateChange<T>: Sendable where T: Sendable {
    public let old: T
    public let new: T
}

// MARK: - Subscription Token

/// A token that can be used to cancel a subscription.
public final class SubscriptionToken: Sendable {
    private let onCancel: @Sendable () -> Void
    private let _isCancelled = StateLock(false)

    public var isCancelled: Bool {
        _isCancelled.value
    }

    init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        let shouldCancel = _isCancelled.withLock { cancelled -> Bool in
            if cancelled { return false }
            cancelled = true
            return true
        }
        if shouldCancel {
            onCancel()
        }
    }

    deinit {
        cancel()
    }
}

// MARK: - Subscriber

/// Internal type representing a state subscriber.
struct Subscriber<T: Sendable>: Sendable {
    let id: UUID
    let continuation: AsyncStream<T>.Continuation
}

// MARK: - State Actor

/// The core state management actor.
/// Provides thread-safe state access and mutation with subscription support.
public actor StateActor {
    // MARK: - Properties

    /// The current state, accessible synchronously via the lock.
    private let stateLock: StateLock<RowndState>

    /// Subscribers organized by key path identifier.
    private var subscribers: [String: [Any]] = [:]

    /// Middleware to execute on state changes.
    private var middleware: [(RowndState, RowndState) async -> Void] = []

    /// Logger for state operations.
    private let log = Logger(subsystem: "io.rownd.sdk", category: "state")

    // MARK: - Initialization

    public init(initialState: RowndState = RowndState()) {
        self.stateLock = StateLock(initialState)
    }

    // MARK: - Synchronous State Access

    /// Get the current state synchronously from any thread.
    /// This is safe to call from non-async contexts.
    public nonisolated var state: RowndState {
        stateLock.value
    }

    /// Get a specific slice of state synchronously.
    public nonisolated func getState<T>(_ keyPath: KeyPath<RowndState, T>) -> T {
        stateLock.value[keyPath: keyPath]
    }

    // MARK: - State Mutation

    /// Update the state with a mutation closure.
    /// All mutations are serialized through the actor.
    @discardableResult
    public func update<T>(_ keyPath: WritableKeyPath<RowndState, T>, value: T) async -> RowndState {
        let oldState = stateLock.value
        let newState = stateLock.withLock { state -> RowndState in
            state[keyPath: keyPath] = value
            state.lastUpdateTs = Date()
            return state
        }

        await notifySubscribers(oldState: oldState, newState: newState)
        await runMiddleware(oldState: oldState, newState: newState)

        return newState
    }

    /// Update the state with a mutation closure for complex updates.
    @discardableResult
    public func mutate(_ mutation: (inout RowndState) -> Void) async -> RowndState {
        let oldState = stateLock.value
        let newState = stateLock.withLock { state -> RowndState in
            mutation(&state)
            state.lastUpdateTs = Date()
            return state
        }

        await notifySubscribers(oldState: oldState, newState: newState)
        await runMiddleware(oldState: oldState, newState: newState)

        return newState
    }

    /// Replace the entire state (used for initialization/reload).
    @discardableResult
    public func replaceState(_ newState: RowndState) async -> RowndState {
        let oldState = stateLock.value
        stateLock.withLock { state in
            state = newState
        }

        await notifySubscribers(oldState: oldState, newState: newState)
        await runMiddleware(oldState: oldState, newState: newState)

        return newState
    }

    // MARK: - Subscriptions

    /// Subscribe to changes in a specific state slice using AsyncStream.
    public func subscribe<T: Sendable & Equatable>(
        to keyPath: KeyPath<RowndState, T>
    ) -> (stream: AsyncStream<T>, token: SubscriptionToken) {
        let id = UUID()
        let keyPathId = String(describing: keyPath)

        var continuation: AsyncStream<T>.Continuation!
        let stream = AsyncStream<T> { cont in
            continuation = cont
            // Emit current value immediately
            cont.yield(self.stateLock.value[keyPath: keyPath])
        }

        let subscriber = Subscriber<T>(id: id, continuation: continuation)

        // Store subscriber
        if subscribers[keyPathId] == nil {
            subscribers[keyPathId] = []
        }
        subscribers[keyPathId]?.append(subscriber)

        // Create cancellation token
        let token = SubscriptionToken { [weak self] in
            Task { [weak self] in
                await self?.removeSubscriber(id: id, keyPathId: keyPathId)
            }
        }

        return (stream, token)
    }

    /// Subscribe to the entire state.
    public func subscribeToAll() -> (stream: AsyncStream<RowndState>, token: SubscriptionToken) {
        let id = UUID()
        let keyPathId = "__all__"

        var continuation: AsyncStream<RowndState>.Continuation!
        let stream = AsyncStream<RowndState> { cont in
            continuation = cont
            cont.yield(self.stateLock.value)
        }

        let subscriber = Subscriber<RowndState>(id: id, continuation: continuation)

        if subscribers[keyPathId] == nil {
            subscribers[keyPathId] = []
        }
        subscribers[keyPathId]?.append(subscriber)

        let token = SubscriptionToken { [weak self] in
            Task { [weak self] in
                await self?.removeSubscriber(id: id, keyPathId: keyPathId)
            }
        }

        return (stream, token)
    }

    private func removeSubscriber(id: UUID, keyPathId: String) {
        subscribers[keyPathId]?.removeAll { subscriber in
            if let sub = subscriber as? Subscriber<RowndState> {
                if sub.id == id {
                    sub.continuation.finish()
                    return true
                }
            }
            // For type-erased subscribers, we check by casting to known types
            return removeTypedSubscriber(subscriber, id: id)
        }
    }

    private func removeTypedSubscriber(_ subscriber: Any, id: UUID) -> Bool {
        // Check common state types
        if let sub = subscriber as? Subscriber<AuthState>, sub.id == id {
            sub.continuation.finish()
            return true
        }
        if let sub = subscriber as? Subscriber<UserState>, sub.id == id {
            sub.continuation.finish()
            return true
        }
        if let sub = subscriber as? Subscriber<AppConfigState>, sub.id == id {
            sub.continuation.finish()
            return true
        }
        if let sub = subscriber as? Subscriber<PasskeyState>, sub.id == id {
            sub.continuation.finish()
            return true
        }
        if let sub = subscriber as? Subscriber<SignInState>, sub.id == id {
            sub.continuation.finish()
            return true
        }
        if let sub = subscriber as? Subscriber<Bool>, sub.id == id {
            sub.continuation.finish()
            return true
        }
        if let sub = subscriber as? Subscriber<ClockSyncState>, sub.id == id {
            sub.continuation.finish()
            return true
        }
        return false
    }

    // MARK: - Middleware

    /// Add middleware that runs after each state change.
    public func addMiddleware(_ handler: @escaping (RowndState, RowndState) async -> Void) {
        middleware.append(handler)
    }

    private func runMiddleware(oldState: RowndState, newState: RowndState) async {
        for handler in middleware {
            await handler(oldState, newState)
        }
    }

    // MARK: - Notification

    private func notifySubscribers(oldState: RowndState, newState: RowndState) async {
        // Notify all-state subscribers
        if let allSubscribers = subscribers["__all__"] {
            for subscriber in allSubscribers {
                if let sub = subscriber as? Subscriber<RowndState> {
                    sub.continuation.yield(newState)
                }
            }
        }

        // Notify specific keypath subscribers
        await notifyKeyPathSubscribers(oldState: oldState, newState: newState)
    }

    private func notifyKeyPathSubscribers(oldState: RowndState, newState: RowndState) async {
        // Auth state
        if oldState.auth != newState.auth {
            notifyTypedSubscribers(keyPathId: String(describing: \RowndState.auth), value: newState.auth)
        }

        // User state
        if oldState.user != newState.user {
            notifyTypedSubscribers(keyPathId: String(describing: \RowndState.user), value: newState.user)
        }

        // App config state
        if oldState.appConfig != newState.appConfig {
            notifyTypedSubscribers(keyPathId: String(describing: \RowndState.appConfig), value: newState.appConfig)
        }

        // Passkey state
        if oldState.passkeys != newState.passkeys {
            notifyTypedSubscribers(keyPathId: String(describing: \RowndState.passkeys), value: newState.passkeys)
        }

        // Sign in state
        if oldState.signIn != newState.signIn {
            notifyTypedSubscribers(keyPathId: String(describing: \RowndState.signIn), value: newState.signIn)
        }

        // Clock sync state
        if oldState.clockSyncState != newState.clockSyncState {
            notifyTypedSubscribers(keyPathId: String(describing: \RowndState.clockSyncState), value: newState.clockSyncState)
        }

        // isStateLoaded
        if oldState.isStateLoaded != newState.isStateLoaded {
            notifyTypedSubscribers(keyPathId: String(describing: \RowndState.isStateLoaded), value: newState.isStateLoaded)
        }
    }

    private func notifyTypedSubscribers<T: Sendable>(keyPathId: String, value: T) {
        guard let subs = subscribers[keyPathId] else { return }
        for subscriber in subs {
            if let sub = subscriber as? Subscriber<T> {
                sub.continuation.yield(value)
            }
        }
    }
}

// MARK: - OSAllocatedUnfairLock Backport

/// Backport of OSAllocatedUnfairLock for iOS 14-15.
/// Uses os_unfair_lock under the hood.
@available(iOS 14.0, macOS 11.0, *)
final class OSAllocatedUnfairLock: @unchecked Sendable {
    private var _lock = os_unfair_lock()

    func lock() {
        os_unfair_lock_lock(&_lock)
    }

    func unlock() {
        os_unfair_lock_unlock(&_lock)
    }

    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
