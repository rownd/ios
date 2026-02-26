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

// MARK: - Main Actor Dispatch Helper

/// Dispatches work to the MainActor from a nonisolated context.
///
/// Uses `DispatchQueue.main.async` to preserve FIFO ordering of state updates,
/// then hops into a `@MainActor` Task for proper isolation. This prevents the
/// ordering issues that can occur with unstructured Task spawning under
/// high-frequency state changes.
///
/// - Parameters:
///   - instance: The object to operate on (captured weakly)
///   - state: The state value to process
///   - work: The MainActor-isolated work to perform
private func dispatchToMainActor<T: AnyObject, S>(
    _ instance: T,
    state: S,
    work: @escaping @MainActor (T, S) -> Void
) {
    // Use DispatchQueue.main.async for FIFO ordering, then Task for @MainActor isolation
    DispatchQueue.main.async { [weak instance] in
        guard let instance = instance else { return }
        Task { @MainActor in
            work(instance, state)
        }
    }
}

// MARK: - ObservableState

/// Observable wrapper for ReSwift state slices that publishes changes to SwiftUI.
/// Uses @MainActor to ensure all @Published property access is thread-safe.
///
/// ## Thread Safety
/// ReSwift may call `newState(state:)` from any thread. This class uses @MainActor
/// isolation to ensure all @Published property access occurs on the main thread,
/// preventing crashes in swift_retain when accessing Combine's Published wrapper.
///
/// ## State Update Ordering
/// State updates are dispatched through DispatchQueue.main.async to maintain FIFO ordering,
/// then processed on the MainActor. While this preserves ordering of dispatch calls,
/// the actual property updates occur asynchronously. For most SwiftUI use cases this is
/// acceptable since SwiftUI will render the final state.
@MainActor
public class ObservableState<T: Hashable>: ObservableObject, StoreSubscriber, ObservableSubscription
{

    @Published fileprivate(set) public var current: T
    let selector: (RowndState) -> T
    fileprivate let animation: SwiftUI.Animation?
    fileprivate var isSubscribed: Bool = false
    fileprivate var cancellables = Set<AnyCancellable>()

    // MARK: Lifecycle

    nonisolated public init(select selector: @escaping (RowndState) -> (T), animation: SwiftUI.Animation? = nil)
    {
        self.current = selector(Context.currentContext.store.state)
        self.selector = selector
        self.animation = animation
        self.subscribe()
    }

    nonisolated public func subscribe() {
        guard !isSubscribed else { return }
        let selector = self.selector
        Context.currentContext.store.subscribe(self, transform: { $0.select(selector) })
        isSubscribed = true
    }

    func unsubscribe() {
        guard isSubscribed else { return }
        Context.currentContext.store.unsubscribe(self)
        isSubscribed = false
    }

    deinit {
        // Note: deinit is nonisolated even for @MainActor classes.
        // ReSwift's SubscriptionBox holds a weak reference to subscribers,
        // so cleanup happens automatically when this object is deallocated.
    }

    /// Called by ReSwift when state changes. This method is nonisolated because
    /// ReSwift may call it from any thread. Updates are dispatched to MainActor
    /// via DispatchQueue.main to maintain FIFO ordering.
    nonisolated public func newState(state: T) {
        dispatchToMainActor(self, state: state) { instance, newState in
            instance.applyStateUpdate(newState)
        }
    }

    /// Applies the state update on MainActor. Separated from newState to keep
    /// the dispatch logic clean and enable subclass overrides.
    fileprivate func applyStateUpdate(_ state: T) {
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

    public let objectDidChange = PassthroughSubject<DidChangeSubject<T>, Never>()

    public struct DidChangeSubject<S> {
        let old: S
        let new: S
    }
}

public class ObservableThrottledState<T: Hashable>: ObservableState<T> {

    // MARK: Lifecycle

    nonisolated public init(
        select selector: @escaping (RowndState) -> (T), animation: SwiftUI.Animation? = nil,
        throttleInMs: Int
    ) {
        super.init(select: selector, animation: animation)

        objectThrottled
            .throttle(for: .milliseconds(throttleInMs), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                guard let self = self else { return }
                let old = self.current
                self.current = $0
                self.objectDidChange.send(DidChangeSubject(old: old, new: self.current))
            }
            .store(in: &cancellables)
    }

    nonisolated override public func newState(state: T) {
        dispatchToMainActor(self, state: state) { instance, newState in
            instance.applyThrottledStateUpdate(newState)
        }
    }

    fileprivate func applyThrottledStateUpdate(_ state: T) {
        guard current != state else { return }
        if let animation = animation {
            withAnimation(animation) {
                objectThrottled.send(state)
            }
        } else {
            objectThrottled.send(state)
        }
    }

    private let objectThrottled = PassthroughSubject<T, Never>()
}

@MainActor
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

    nonisolated public init(
        select selector: @escaping (RowndState) -> Original,
        transform: @escaping (Original) -> Derived, animation: SwiftUI.Animation? = nil
    ) {
        self.current = transform(selector(Context.currentContext.store.state))
        self.selector = selector
        self.transform = transform
        self.animation = animation
        self.subscribe()
    }

    nonisolated func subscribe() {
        guard !isSubscribed else { return }
        let selector = self.selector
        Context.currentContext.store.subscribe(self, transform: { $0.select(selector) })
        isSubscribed = true
    }

    func unsubscribe() {
        guard isSubscribed else { return }
        Context.currentContext.store.unsubscribe(self)
        isSubscribed = false
    }

    deinit {
        // Note: deinit is nonisolated even for @MainActor classes.
        // ReSwift's SubscriptionBox holds a weak reference to subscribers,
        // so cleanup happens automatically when this object is deallocated.
    }

    nonisolated public func newState(state original: Original) {
        dispatchToMainActor(self, state: original) { instance, newState in
            instance.applyStateUpdate(newState)
        }
    }

    fileprivate func applyStateUpdate(_ original: Original) {
        let old = current
        objectWillChange.send(ChangeSubject(old: old, new: current))

        if let animation = animation {
            withAnimation(animation) {
                current = transform(original)
            }
        } else {
            current = transform(original)
        }
        objectDidChange.send(ChangeSubject(old: old, new: current))
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

    nonisolated public init(
        select selector: @escaping (RowndState) -> Original,
        transform: @escaping (Original) -> Derived, animation: SwiftUI.Animation? = nil,
        throttleInMs: Int
    ) {
        super.init(select: selector, transform: transform, animation: animation)

        objectThrottled
            .throttle(for: .milliseconds(throttleInMs), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                guard let self = self else { return }
                let old = self.current
                self.current = transform($0)
                self.objectDidChange.send(ChangeSubject(old: old, new: self.current))
            }
            .store(in: &cancellables)
    }

    nonisolated override public func newState(state original: Original) {
        dispatchToMainActor(self, state: original) { instance, newState in
            instance.applyThrottledStateUpdate(newState)
        }
    }

    fileprivate func applyThrottledStateUpdate(_ original: Original) {
        if let animation = animation {
            withAnimation(animation) {
                objectThrottled.send(original)
            }
        } else {
            objectThrottled.send(original)
        }
    }

    private let objectThrottled = PassthroughSubject<Original, Never>()
}

extension Store where State == RowndState {

    // BACKWARD COMPATIBLE: Removed @MainActor requirement to restore API compatibility
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
