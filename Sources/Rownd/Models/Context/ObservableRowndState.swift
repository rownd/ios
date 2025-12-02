//
//  ObservableRowndState.swift
//  Rownd
//
//  iOS 17+ @Observable wrapper for automatic SwiftUI integration.
//  For iOS 14-16, use the legacy ObservableState classes.
//

import Combine
import Foundation
import SwiftUI

// MARK: - iOS 17+ Observable State

#if swift(>=5.9)
@available(iOS 17.0, macOS 14.0, *)
@Observable
public final class ObservableRowndState {
    // MARK: - State Properties

    public private(set) var auth: AuthState = AuthState()
    public private(set) var user: UserState = UserState()
    public private(set) var appConfig: AppConfigState = AppConfigState()
    public private(set) var passkeys: PasskeyState = PasskeyState()
    public private(set) var signIn: SignInState = SignInState()
    public private(set) var isStateLoaded: Bool = false
    internal private(set) var clockSyncState: ClockSyncState = .unknown

    // MARK: - Computed Properties

    public var isAuthenticated: Bool {
        auth.accessToken != nil
    }

    public var isInitialized: Bool {
        isStateLoaded && clockSyncState != .waiting
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var observationTask: Task<Void, Never>?

    // MARK: - Initialization

    public init() {
        // Get initial state
        let currentState = Context.currentContext.store.state
        updateFromState(currentState)

        // Subscribe to state changes
        startObserving()
    }

    deinit {
        observationTask?.cancel()
        cancellables.removeAll()
    }

    // MARK: - Observation

    private func startObserving() {
        // Use Combine publisher for reactive updates
        Context.currentContext.store.publisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateFromState(state)
            }
            .store(in: &cancellables)
    }

    private func updateFromState(_ state: RowndState) {
        if auth != state.auth {
            auth = state.auth
        }
        if user != state.user {
            user = state.user
        }
        if appConfig != state.appConfig {
            appConfig = state.appConfig
        }
        if passkeys != state.passkeys {
            passkeys = state.passkeys
        }
        if signIn != state.signIn {
            signIn = state.signIn
        }
        if isStateLoaded != state.isStateLoaded {
            isStateLoaded = state.isStateLoaded
        }
        if clockSyncState != state.clockSyncState {
            clockSyncState = state.clockSyncState
        }
    }
}
#endif

// MARK: - Legacy Observable State (iOS 14+)

/// Observable state wrapper for SwiftUI that uses Combine internally.
/// This is the backward-compatible replacement for the ReSwift-based ObservableState.
public final class LegacyObservableState<T: Hashable>: ObservableObject {
    @Published public private(set) var current: T

    private let selector: (RowndState) -> T
    private let animation: SwiftUI.Animation?
    private var cancellable: AnyCancellable?
    private let store: StateStore

    public let objectDidChange = PassthroughSubject<StateChange<T>, Never>()

    public init(
        store: StateStore,
        selector: @escaping (RowndState) -> T,
        animation: SwiftUI.Animation? = nil
    ) {
        self.store = store
        self.selector = selector
        self.animation = animation
        self.current = selector(store.state)

        subscribe()
    }

    private func subscribe() {
        cancellable = store.publisher()
            .map { [selector] state in selector(state) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self = self else { return }
                let oldValue = self.current
                guard oldValue != newValue else { return }

                if let animation = self.animation {
                    withAnimation(animation) {
                        self.current = newValue
                    }
                } else {
                    self.current = newValue
                }

                self.objectDidChange.send(StateChange(old: oldValue, new: newValue))
            }
    }

    public func unsubscribe() {
        cancellable?.cancel()
        cancellable = nil
    }

    deinit {
        unsubscribe()
    }
}

// MARK: - Legacy Throttled Observable State

/// Throttled observable state wrapper for SwiftUI.
public final class LegacyObservableThrottledState<T: Hashable>: ObservableObject {
    @Published public private(set) var current: T

    private let selector: (RowndState) -> T
    private let animation: SwiftUI.Animation?
    private var cancellable: AnyCancellable?
    private let store: StateStore
    private let throttleMs: Int

    public let objectDidChange = PassthroughSubject<StateChange<T>, Never>()

    public init(
        store: StateStore,
        selector: @escaping (RowndState) -> T,
        animation: SwiftUI.Animation? = nil,
        throttleInMs: Int = 350
    ) {
        self.store = store
        self.selector = selector
        self.animation = animation
        self.throttleMs = throttleInMs
        self.current = selector(store.state)

        subscribe()
    }

    private func subscribe() {
        cancellable = store.publisher()
            .map { [selector] state in selector(state) }
            .removeDuplicates()
            .throttle(for: .milliseconds(throttleMs), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self = self else { return }
                let oldValue = self.current
                guard oldValue != newValue else { return }

                if let animation = self.animation {
                    withAnimation(animation) {
                        self.current = newValue
                    }
                } else {
                    self.current = newValue
                }

                self.objectDidChange.send(StateChange(old: oldValue, new: newValue))
            }
    }

    public func unsubscribe() {
        cancellable?.cancel()
        cancellable = nil
    }

    deinit {
        unsubscribe()
    }
}

// MARK: - Legacy Derived Observable State

/// Observable state that derives a new value from the source state.
public final class LegacyObservableDerivedState<Original: Hashable, Derived: Hashable>: ObservableObject {
    @Published public private(set) var current: Derived

    private let selector: (RowndState) -> Original
    private let transform: (Original) -> Derived
    private let animation: SwiftUI.Animation?
    private var cancellable: AnyCancellable?
    private let store: StateStore

    public let objectWillChange = PassthroughSubject<StateChange<Derived>, Never>()
    public let objectDidChange = PassthroughSubject<StateChange<Derived>, Never>()

    public init(
        store: StateStore,
        selector: @escaping (RowndState) -> Original,
        transform: @escaping (Original) -> Derived,
        animation: SwiftUI.Animation? = nil
    ) {
        self.store = store
        self.selector = selector
        self.transform = transform
        self.animation = animation
        self.current = transform(selector(store.state))

        subscribe()
    }

    private func subscribe() {
        cancellable = store.publisher()
            .map { [selector] state in selector(state) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] originalValue in
                guard let self = self else { return }
                let newValue = self.transform(originalValue)
                let oldValue = self.current
                guard oldValue != newValue else { return }

                self.objectWillChange.send(StateChange(old: oldValue, new: newValue))

                if let animation = self.animation {
                    withAnimation(animation) {
                        self.current = newValue
                    }
                } else {
                    self.current = newValue
                }

                self.objectDidChange.send(StateChange(old: oldValue, new: newValue))
            }
    }

    public func unsubscribe() {
        cancellable?.cancel()
        cancellable = nil
    }

    deinit {
        unsubscribe()
    }
}

// MARK: - Legacy Derived Throttled Observable State

/// Throttled observable state that derives a new value from the source state.
public final class LegacyObservableDerivedThrottledState<Original: Hashable, Derived: Hashable>: ObservableObject {
    @Published public private(set) var current: Derived

    private let selector: (RowndState) -> Original
    private let transform: (Original) -> Derived
    private let animation: SwiftUI.Animation?
    private var cancellable: AnyCancellable?
    private let store: StateStore
    private let throttleMs: Int

    public let objectDidChange = PassthroughSubject<StateChange<Derived>, Never>()

    public init(
        store: StateStore,
        selector: @escaping (RowndState) -> Original,
        transform: @escaping (Original) -> Derived,
        animation: SwiftUI.Animation? = nil,
        throttleInMs: Int = 350
    ) {
        self.store = store
        self.selector = selector
        self.transform = transform
        self.animation = animation
        self.throttleMs = throttleInMs
        self.current = transform(selector(store.state))

        subscribe()
    }

    private func subscribe() {
        cancellable = store.publisher()
            .map { [selector] state in selector(state) }
            .removeDuplicates()
            .throttle(for: .milliseconds(throttleMs), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] originalValue in
                guard let self = self else { return }
                let newValue = self.transform(originalValue)
                let oldValue = self.current
                guard oldValue != newValue else { return }

                if let animation = self.animation {
                    withAnimation(animation) {
                        self.current = newValue
                    }
                } else {
                    self.current = newValue
                }

                self.objectDidChange.send(StateChange(old: oldValue, new: newValue))
            }
    }

    public func unsubscribe() {
        cancellable?.cancel()
        cancellable = nil
    }

    deinit {
        unsubscribe()
    }
}
