//
//  ReSwiftObserver.swift
//  framework
//
//  Created by Matt Hamann on 6/27/22.
//
//  This file provides backward-compatible observable state classes that wrap
//  the new StateStore. The public API remains the same for existing consumers.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Backward Compatible Observable State

/// Observable state wrapper for SwiftUI - backward compatible with the old ReSwift-based API.
/// Use this with @StateObject in SwiftUI views.
public class ObservableState<T: Hashable>: ObservableObject, ObservableSubscription {
    @Published fileprivate(set) public var current: T

    let selector: (RowndState) -> T
    fileprivate let animation: SwiftUI.Animation?
    fileprivate var cancellable: AnyCancellable?
    fileprivate var isSubscribed: Bool = false

    public let objectDidChange = PassthroughSubject<DidChangeSubject<T>, Never>()

    public struct DidChangeSubject<S> {
        public let old: S
        public let new: S
    }

    // MARK: Lifecycle

    public init(select selector: @escaping (RowndState) -> T, animation: SwiftUI.Animation? = nil) {
        self.selector = selector
        self.animation = animation
        self.current = selector(Context.currentContext.store.state)
        self.subscribe()
    }

    public func subscribe() {
        guard !isSubscribed else { return }
        isSubscribed = true

        cancellable = Context.currentContext.store.publisher()
            .map { [selector] state in selector(state) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.handleNewState(newValue)
            }
    }

    func unsubscribe() {
        guard isSubscribed else { return }
        cancellable?.cancel()
        cancellable = nil
        isSubscribed = false
    }

    deinit {
        unsubscribe()
    }

    fileprivate func handleNewState(_ state: T) {
        guard current != state else { return }
        let old = current

        if let animation = animation {
            withAnimation(animation) {
                current = state
            }
        } else {
            current = state
        }

        objectDidChange.send(DidChangeSubject(old: old, new: current))
    }

    /// Legacy method for ReSwift compatibility - now receives state from Combine publisher.
    public func newState(state: T) {
        DispatchQueue.main.async { [weak self] in
            self?.handleNewState(state)
        }
    }
}

// MARK: - Throttled Observable State

public class ObservableThrottledState<T: Hashable>: ObservableState<T> {
    private let throttleMs: Int
    private let throttledSubject = PassthroughSubject<T, Never>()
    private var throttleCancellable: AnyCancellable?

    public init(
        select selector: @escaping (RowndState) -> T,
        animation: SwiftUI.Animation? = nil,
        throttleInMs: Int
    ) {
        self.throttleMs = throttleInMs
        super.init(select: selector, animation: animation)

        throttleCancellable = throttledSubject
            .throttle(for: .milliseconds(throttleMs), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] value in
                guard let self = self else { return }
                if let animation = self.animation {
                    withAnimation(animation) {
                        self.current = value
                    }
                } else {
                    self.current = value
                }
            }
    }

    override func handleNewState(_ state: T) {
        guard current != state else { return }
        let old = current
        throttledSubject.send(state)
        objectDidChange.send(DidChangeSubject(old: old, new: current))
    }

    override func unsubscribe() {
        throttleCancellable?.cancel()
        throttleCancellable = nil
        super.unsubscribe()
    }
}

// MARK: - Derived Observable State

public class ObservableDerivedState<Original: Hashable, Derived: Hashable>: ObservableObject, ObservableSubscription {
    @Published public var current: Derived

    let selector: (RowndState) -> Original
    let transform: (Original) -> Derived
    fileprivate let animation: SwiftUI.Animation?
    fileprivate var cancellable: AnyCancellable?
    fileprivate var isSubscribed: Bool = false

    public let objectWillChange = PassthroughSubject<ChangeSubject<Derived>, Never>()
    public let objectDidChange = PassthroughSubject<ChangeSubject<Derived>, Never>()

    public struct ChangeSubject<DerivedSub> {
        public let old: DerivedSub
        public let new: DerivedSub
    }

    public init(
        select selector: @escaping (RowndState) -> Original,
        transform: @escaping (Original) -> Derived,
        animation: SwiftUI.Animation? = nil
    ) {
        self.selector = selector
        self.transform = transform
        self.animation = animation
        self.current = transform(selector(Context.currentContext.store.state))
        self.subscribe()
    }

    func subscribe() {
        guard !isSubscribed else { return }
        isSubscribed = true

        cancellable = Context.currentContext.store.publisher()
            .map { [selector] state in selector(state) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] originalValue in
                self?.handleNewState(originalValue)
            }
    }

    func unsubscribe() {
        guard isSubscribed else { return }
        cancellable?.cancel()
        cancellable = nil
        isSubscribed = false
    }

    deinit {
        unsubscribe()
    }

    fileprivate func handleNewState(_ original: Original) {
        let newValue = transform(original)
        guard current != newValue else { return }
        let old = current

        objectWillChange.send(ChangeSubject(old: old, new: newValue))

        if let animation = animation {
            withAnimation(animation) {
                current = newValue
            }
        } else {
            current = newValue
        }

        objectDidChange.send(ChangeSubject(old: old, new: current))
    }

    /// Legacy method for ReSwift compatibility.
    public func newState(state original: Original) {
        DispatchQueue.main.async { [weak self] in
            self?.handleNewState(original)
        }
    }
}

// MARK: - Derived Throttled Observable State

public class ObservableDerivedThrottledState<Original: Hashable, Derived: Hashable>: ObservableDerivedState<Original, Derived> {
    private let throttleMs: Int
    private let throttledSubject = PassthroughSubject<Original, Never>()
    private var throttleCancellable: AnyCancellable?

    public init(
        select selector: @escaping (RowndState) -> Original,
        transform: @escaping (Original) -> Derived,
        animation: SwiftUI.Animation? = nil,
        throttleInMs: Int
    ) {
        self.throttleMs = throttleInMs
        super.init(select: selector, transform: transform, animation: animation)

        throttleCancellable = throttledSubject
            .throttle(for: .milliseconds(throttleMs), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] value in
                guard let self = self else { return }
                let newValue = self.transform(value)
                if let animation = self.animation {
                    withAnimation(animation) {
                        self.current = newValue
                    }
                } else {
                    self.current = newValue
                }
            }
    }

    override func handleNewState(_ original: Original) {
        let old = current
        throttledSubject.send(original)
        objectDidChange.send(ChangeSubject(old: old, new: current))
    }

    override func unsubscribe() {
        throttleCancellable?.cancel()
        throttleCancellable = nil
        super.unsubscribe()
    }
}

// MARK: - StateStore Extensions for Backward Compatibility

extension StateStore {
    /// Subscribe to a state slice - backward compatible with old ReSwift Store API.
    public func subscribe<T: Hashable>(
        select selector: @escaping (RowndState) -> T,
        animation: SwiftUI.Animation? = nil
    ) -> ObservableState<T> {
        ObservableState(select: selector, animation: animation)
    }

    /// Subscribe to a derived state - backward compatible with old ReSwift Store API.
    public func subscribe<Original: Hashable, Derived: Hashable>(
        select selector: @escaping (RowndState) -> Original,
        transform: @escaping (Original) -> Derived,
        animation: SwiftUI.Animation? = nil
    ) -> ObservableDerivedState<Original, Derived> {
        ObservableDerivedState(select: selector, transform: transform, animation: animation)
    }

    /// Subscribe to a throttled state slice - backward compatible with old ReSwift Store API.
    public func subscribeThrottled<T: Hashable>(
        select selector: @escaping (RowndState) -> T,
        throttleInMs: Int = 350,
        animation: SwiftUI.Animation? = nil
    ) -> ObservableThrottledState<T> {
        ObservableThrottledState(select: selector, animation: animation, throttleInMs: throttleInMs)
    }

    /// Subscribe to a throttled derived state - backward compatible with old ReSwift Store API.
    public func subscribeThrottled<Original: Hashable, Derived: Hashable>(
        select selector: @escaping (RowndState) -> Original,
        transform: @escaping (Original) -> Derived,
        throttleInMs: Int = 350,
        animation: SwiftUI.Animation? = nil
    ) -> ObservableDerivedThrottledState<Original, Derived> {
        ObservableDerivedThrottledState(
            select: selector,
            transform: transform,
            animation: animation,
            throttleInMs: throttleInMs
        )
    }
}

// MARK: - Protocol

protocol ObservableSubscription {
    func unsubscribe()
}

protocol Initializable {
    init()
}
