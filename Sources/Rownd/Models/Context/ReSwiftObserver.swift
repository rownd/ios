//
//  ReSwiftObserver.swift
//  framework
//
//  Created by Matt Hamann on 6/27/22.
//

import Combine
import Foundation
import ReSwift
import SwiftUI

// MARK: - Main Thread Dispatch Helper

/// Helper to centralize main-thread dispatch with weak self handling.
/// Reduces duplication and ensures consistent patterns across observable state types.
private func dispatchOnMain<T: AnyObject>(_ instance: T, execute work: @escaping (T) -> Void) {
    DispatchQueue.main.async { [weak instance] in
        guard let instance = instance else { return }
        work(instance)
    }
}

public class ObservableState<T: Hashable>: ObservableObject, StoreSubscriber, ObservableSubscription
{

    @Published fileprivate(set) public var current: T
    let selector: (RowndState) -> T
    fileprivate let animation: SwiftUI.Animation?
    fileprivate var isSubscribed: Bool = false
    fileprivate var cancellables = Set<AnyCancellable>()

    // MARK: Lifecycle

    public init(select selector: @escaping (RowndState) -> (T), animation: SwiftUI.Animation? = nil)
    {
        self.current = selector(Context.currentContext.store.state)
        self.selector = selector
        self.animation = animation
        self.subscribe()
    }

    public func subscribe() {
        guard !isSubscribed else { return }
        // Capture selector directly to avoid retaining self in the transform closure
        let selector = self.selector
        dispatchOnMain(self) { instance in
            guard !instance.isSubscribed else { return }
            Context.currentContext.store.subscribe(
                instance, transform: { $0.select(selector) })
            instance.isSubscribed = true
        }
    }

    func unsubscribe() {
        guard isSubscribed else { return }
        dispatchOnMain(self) { instance in
            guard instance.isSubscribed else { return }
            Context.currentContext.store.unsubscribe(instance)
            instance.isSubscribed = false
        }
    }

    deinit {
        unsubscribe()
    }

    public func newState(state: T) {
        // All @Published property access must happen on main thread
        dispatchOnMain(self) { instance in
            guard instance.current != state else { return }
            let old = instance.current
            if let animation = instance.animation {
                withAnimation(animation) {
                    instance.current = state
                }
            } else {
                instance.current = state
            }
            instance.objectDidChange.send(DidChangeSubject(old: old, new: instance.current))
        }
    }

    public let objectDidChange = PassthroughSubject<DidChangeSubject<T>, Never>()

    public struct DidChangeSubject<S> {
        let old: S
        let new: S
    }
}

public class ObservableThrottledState<T: Hashable>: ObservableState<T> {

    // MARK: Lifecycle

    public init(
        select selector: @escaping (RowndState) -> (T), animation: SwiftUI.Animation? = nil,
        throttleInMs: Int
    ) {
        super.init(select: selector, animation: animation)

        objectThrottled
            .throttle(for: .milliseconds(throttleInMs), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in self?.current = $0 }
            .store(in: &cancellables)
    }

    override public func newState(state: T) {
        // All @Published property access must happen on main thread to avoid crashes
        // in swift_retain when accessing Combine's Published wrapper from background threads
        dispatchOnMain(self) { instance in
            guard instance.current != state else { return }
            let old = instance.current
            if let animation = instance.animation {
                withAnimation(animation) {
                    instance.objectThrottled.send(state)
                }
            } else {
                instance.objectThrottled.send(state)
            }
            instance.objectDidChange.send(DidChangeSubject(old: old, new: instance.current))
        }
    }

    private let objectThrottled = PassthroughSubject<T, Never>()
}

public class ObservableDerivedState<Original: Hashable, Derived: Hashable>: ObservableObject,
    StoreSubscriber, ObservableSubscription
{
    @Published public var current: Derived

    let selector: (RowndState) -> Original
    let transform: (Original) -> Derived
    fileprivate let animation: SwiftUI.Animation?
    fileprivate var isSubscribed: Bool = false
    fileprivate var cancellables = Set<AnyCancellable>()

    // MARK: Lifecycle

    public init(
        select selector: @escaping (RowndState) -> Original,
        transform: @escaping (Original) -> Derived, animation: SwiftUI.Animation? = nil
    ) {
        self.current = transform(selector(Context.currentContext.store.state))
        self.selector = selector
        self.transform = transform
        self.animation = animation
        self.subscribe()
    }

    func subscribe() {
        guard !isSubscribed else { return }
        // Capture selector directly to avoid retaining self in the transform closure
        let selector = self.selector
        dispatchOnMain(self) { instance in
            guard !instance.isSubscribed else { return }
            Context.currentContext.store.subscribe(
                instance, transform: { $0.select(selector) })
            instance.isSubscribed = true
        }
    }

    func unsubscribe() {
        guard isSubscribed else { return }
        dispatchOnMain(self) { instance in
            guard instance.isSubscribed else { return }
            Context.currentContext.store.unsubscribe(instance)
            instance.isSubscribed = false
        }
    }

    deinit {
        unsubscribe()
    }

    public func newState(state original: Original) {
        dispatchOnMain(self) { instance in
            let old = instance.current
            instance.objectWillChange.send(ChangeSubject(old: old, new: instance.current))

            if let animation = instance.animation {
                withAnimation(animation) {
                    instance.current = instance.transform(original)
                }
            } else {
                instance.current = instance.transform(original)
            }
            instance.objectDidChange.send(ChangeSubject(old: old, new: instance.current))
        }
    }

    public let objectWillChange = PassthroughSubject<ChangeSubject<Derived>, Never>()
    public let objectDidChange = PassthroughSubject<ChangeSubject<Derived>, Never>()

    public struct ChangeSubject<DerivedSub> {
        let old: DerivedSub
        let new: DerivedSub
    }
}

public class ObservableDerivedThrottledState<Original: Hashable, Derived: Hashable>:
    ObservableDerivedState<Original, Derived>
{

    // MARK: Lifecycle

    public init(
        select selector: @escaping (RowndState) -> Original,
        transform: @escaping (Original) -> Derived, animation: SwiftUI.Animation? = nil,
        throttleInMs: Int
    ) {
        super.init(select: selector, transform: transform, animation: animation)

        objectThrottled
            .throttle(for: .milliseconds(throttleInMs), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.current = transform($0)
            }
            .store(in: &cancellables)
    }

    override public func newState(state original: Original) {
        dispatchOnMain(self) { instance in
            let old = instance.current
            if let animation = instance.animation {
                withAnimation(animation) {
                    instance.objectThrottled.send(original)
                }
            } else {
                instance.objectThrottled.send(original)
            }
            instance.objectDidChange.send(ChangeSubject(old: old, new: instance.current))
        }
    }

    private let objectThrottled = PassthroughSubject<Original, Never>()
}

extension Store where State == RowndState {

    public func subscribe<T>(
        select selector: @escaping (RowndState) -> (T), animation: SwiftUI.Animation? = nil
    ) -> ObservableState<T> {
        ObservableState(select: selector, animation: animation)
    }

    public func subscribe<Original, Derived>(
        select selector: @escaping (RowndState) -> (Original),
        transform: @escaping (Original) -> Derived, animation: SwiftUI.Animation? = nil
    ) -> ObservableDerivedState<Original, Derived> {
        ObservableDerivedState(select: selector, transform: transform, animation: animation)
    }

    public func subscribeThrottled<T>(
        select selector: @escaping (RowndState) -> (T), throttleInMs: Int = 350,
        animation: SwiftUI.Animation? = nil
    ) -> ObservableThrottledState<T> {
        ObservableThrottledState(select: selector, animation: animation, throttleInMs: throttleInMs)
    }

    public func subscribeThrottled<Original, Derived>(
        select selector: @escaping (RowndState) -> (Original),
        transform: @escaping (Original) -> Derived, throttleInMs: Int = 350,
        animation: SwiftUI.Animation? = nil
    ) -> ObservableDerivedThrottledState<Original, Derived> {
        ObservableDerivedThrottledState(
            select: selector, transform: transform, animation: animation, throttleInMs: throttleInMs
        )
    }
}

protocol ObservableSubscription {
    func unsubscribe()
}

protocol Initializable {
    init()
}
