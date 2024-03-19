//
//  ReSwiftObserver.swift
//  framework
//
//  Created by Matt Hamann on 6/27/22.
//

import Foundation

import ReSwift
import SwiftUI
import Combine

public class ObservableState<T: Hashable>: ObservableObject, StoreSubscriber, ObservableSubscription {
    
    @Published fileprivate(set) public var current: T
    let selector: (RowndState) -> T
    fileprivate let animation: SwiftUI.Animation?
    fileprivate var isSubscribed: Bool = false
    fileprivate var cancellables = Set<AnyCancellable>()
    
    // MARK: Lifecycle
    
    public init(select selector: @escaping (RowndState) -> (T), animation: SwiftUI.Animation? = nil) {
        self.current = selector(store.state)
        self.selector = selector
        self.animation = animation
        self.subscribe()
    }
    
    public func subscribe() {
        guard !isSubscribed else { return }
        store.subscribe(self, transform: { [self] in $0.select(selector) })
        isSubscribed = true
    }
    
    func unsubscribe() {
        guard isSubscribed else { return }
        store.unsubscribe(self)
        isSubscribed = false
    }
    
    deinit {
        unsubscribe()
    }
    
    public func newState(state: T) {
        guard self.current != state else { return }
        DispatchQueue.main.async {
            let old = self.current
            if let animation = self.animation {
                withAnimation(animation) {
                    self.current = state
                }
            } else {
                self.current = state
            }
            self.objectDidChange.send(DidChangeSubject(old: old, new: self.current))
        }
    }
    
    public let objectDidChange = PassthroughSubject<DidChangeSubject<T>,Never>()
    
    public struct DidChangeSubject<S> {
        let old: S
        let new: S
    }
}

public class ObservableThrottledState<T: Hashable>: ObservableState<T> {
    
    // MARK: Lifecycle
    
    public init(select selector: @escaping (RowndState) -> (T), animation: SwiftUI.Animation? = nil, throttleInMs: Int) {
        super.init(select: selector, animation: animation)
        
        objectThrottled
            .throttle(for: .milliseconds(throttleInMs), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in self?.current = $0 }
            .store(in: &cancellables)
    }
    
    override public func newState(state: T) {
        guard self.current != state else { return }
        DispatchQueue.main.async {
            let old = self.current
            if let animation = self.animation {
                withAnimation(animation) {
                    self.objectThrottled.send(state)
                }
            } else {
                self.objectThrottled.send(state)
            }
            self.objectDidChange.send(DidChangeSubject(old: old, new: self.current))
        }
    }
    
    private let objectThrottled = PassthroughSubject<T, Never>()
}


public class ObservableDerivedState<Original: Hashable, Derived: Hashable>: ObservableObject, StoreSubscriber, ObservableSubscription {
    @Published public var current: Derived
    
    let selector: (RowndState) -> Original
    let transform: (Original) -> Derived
    fileprivate let animation: SwiftUI.Animation?
    fileprivate var isSubscribed: Bool = false
    fileprivate var cancellables = Set<AnyCancellable>()
    
    // MARK: Lifecycle
    
    public init(select selector: @escaping (RowndState) -> Original, transform: @escaping (Original) -> Derived, animation: SwiftUI.Animation? = nil) {
        self.current = transform(selector(store.state))
        self.selector = selector
        self.transform = transform
        self.animation = animation
        self.subscribe()
    }
    
    func subscribe() {
        guard !isSubscribed else { return }
        store.subscribe(self, transform: { [self] in $0.select(selector) })
        isSubscribed = true
    }
    
    func unsubscribe() {
        guard isSubscribed else { return }
        store.unsubscribe(self)
        isSubscribed = false
    }
    
    deinit {
        unsubscribe()
    }
    
    public func newState(state original: Original) {
        DispatchQueue.main.async {
            let old = self.current
            self.objectWillChange.send(ChangeSubject(old: old, new: self.current))
            
            if let animation = self.animation {
                withAnimation(animation) {
                    self.current = self.transform(original)
                }
            } else {
                self.current = self.transform(original)
            }
            self.objectDidChange.send(ChangeSubject(old: old, new: self.current))
        }
    }
    
    public let objectWillChange = PassthroughSubject<ChangeSubject<Derived>,Never>()
    public let objectDidChange = PassthroughSubject<ChangeSubject<Derived>,Never>()
    
    public struct ChangeSubject<DerivedSub> {
        let old: DerivedSub
        let new: DerivedSub
    }
}


public class ObservableDerivedThrottledState<Original: Hashable, Derived: Hashable>: ObservableDerivedState<Original, Derived> {
    
    // MARK: Lifecycle
    
    public init(select selector: @escaping (RowndState) -> Original, transform: @escaping (Original) -> Derived, animation: SwiftUI.Animation? = nil, throttleInMs: Int) {
        super.init(select: selector, transform: transform, animation: animation)
        
        objectThrottled
            .throttle(for: .milliseconds(throttleInMs), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.current = transform($0)
            }
            .store(in: &cancellables)
    }
    
    override public func newState(state original: Original) {
        let old = current
        if let animation = animation {
            withAnimation(animation) {
                objectThrottled.send(original)
            }
        } else {
            objectThrottled.send(original)
        }
        
        DispatchQueue.main.async { self.objectDidChange.send(ChangeSubject(old: old, new: self.current)) }
    }
    
    private let objectThrottled = PassthroughSubject<Original, Never>()
}

public extension Store where State == RowndState {
    
    func subscribe<T>(select selector: @escaping (RowndState) -> (T), animation: SwiftUI.Animation? = nil) -> ObservableState<T> {
        ObservableState(select: selector, animation: animation)
    }
    
    func subscribe<Original, Derived>(select selector: @escaping (RowndState) -> (Original), transform: @escaping (Original) -> Derived, animation: SwiftUI.Animation? = nil) -> ObservableDerivedState<Original, Derived> {
        ObservableDerivedState(select: selector, transform: transform, animation: animation)
    }
    
    func subscribeThrottled<T>(select selector: @escaping (RowndState) -> (T), throttleInMs: Int = 350, animation: SwiftUI.Animation? = nil) -> ObservableThrottledState<T> {
        ObservableThrottledState(select: selector, animation: animation, throttleInMs: throttleInMs)
    }
    
    func subscribeThrottled<Original, Derived>(select selector: @escaping (RowndState) -> (Original), transform: @escaping (Original) -> Derived, throttleInMs: Int = 350, animation: SwiftUI.Animation? = nil) -> ObservableDerivedThrottledState<Original, Derived> {
        ObservableDerivedThrottledState(select: selector, transform: transform, animation: animation, throttleInMs: throttleInMs)
    }
}

protocol ObservableSubscription {
    func unsubscribe()
}

protocol Initializable {
    init()
}
