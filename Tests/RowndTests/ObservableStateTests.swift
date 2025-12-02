//
//  ObservableStateTests.swift
//  RowndTests
//
//  Tests for thread safety and memory management in ObservableState classes.
//  These tests reproduce crashes that occurred when newState was called from
//  background threads or when observers were deallocated during state updates.
//

import Combine
import Foundation
import Testing

@testable import Rownd

struct ObservableStateTests {

    /// Tests that ObservableState can handle state updates from concurrent tasks.
    @Test
    func observableStateHandlesBackgroundThreadStateUpdates() async throws {
        let store = createStore()
        _ = Context(store)

        // Create an observable state
        let observer = store.subscribe(select: { $0.clockSyncState })

        let iterations = 100

        // Dispatch state changes from concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let state: ClockSyncState = (i % 2 == 0) ? .waiting : .synced
                    await store.setClockSync(state)
                }
            }
        }

        // If we reach here without crashing, the test passes
        _ = observer
    }

    /// Tests that ObservableThrottledState can handle state updates from concurrent tasks.
    @Test
    func observableThrottledStateHandlesBackgroundThreadStateUpdates() async throws {
        let store = createStore()
        _ = Context(store)

        // Create a throttled observable state
        let observer = store.subscribeThrottled(select: { $0.clockSyncState }, throttleInMs: 50)

        let iterations = 100

        // Dispatch state changes from concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let state: ClockSyncState = (i % 2 == 0) ? .waiting : .synced
                    await store.setClockSync(state)
                }
            }
        }

        // If we reach here without crashing, the test passes
        _ = observer
    }

    /// Tests that ObservableDerivedState can handle state updates from concurrent tasks.
    @Test
    func observableDerivedStateHandlesBackgroundThreadStateUpdates() async throws {
        let store = createStore()
        _ = Context(store)

        // Create a derived observable state
        let observer = store.subscribe(
            select: { $0.clockSyncState },
            transform: { state -> String in
                switch state {
                case .waiting: return "waiting"
                case .synced: return "synced"
                case .unknown: return "unknown"
                case .failed: return "failed"
                }
            }
        )

        let iterations = 100

        // Dispatch state changes from concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let state: ClockSyncState = (i % 2 == 0) ? .waiting : .synced
                    await store.setClockSync(state)
                }
            }
        }

        // If we reach here without crashing, the test passes
        _ = observer
    }

    /// Tests that ObservableDerivedThrottledState can handle state updates from concurrent tasks.
    @Test
    func observableDerivedThrottledStateHandlesBackgroundThreadStateUpdates() async throws {
        let store = createStore()
        _ = Context(store)

        // Create a derived throttled observable state
        let observer = store.subscribeThrottled(
            select: { $0.clockSyncState },
            transform: { state -> String in
                switch state {
                case .waiting: return "waiting"
                case .synced: return "synced"
                case .unknown: return "unknown"
                case .failed:
                    return "failed"
                }
            },
            throttleInMs: 50
        )

        let iterations = 100

        // Dispatch state changes from concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let state: ClockSyncState = (i % 2 == 0) ? .waiting : .synced
                    await store.setClockSync(state)
                }
            }
        }

        // If we reach here without crashing, the test passes
        _ = observer
    }

    /// Tests that rapidly creating and destroying observers while dispatching state
    /// does not crash.
    @Test
    func rapidObserverCreationAndDestructionDoesNotCrash() async throws {
        let store = createStore()
        _ = Context(store)

        let iterations = 50

        // Dispatch state changes
        let dispatchTask = Task {
            for i in 0..<iterations {
                let state: ClockSyncState = (i % 2 == 0) ? .waiting : .synced
                await store.setClockSync(state)
            }
        }

        // Rapidly create and destroy observers
        for _ in 0..<iterations {
            autoreleasepool {
                let obs1 = store.subscribe(select: { $0.clockSyncState })
                let obs2 = store.subscribeThrottled(select: { $0.clockSyncState }, throttleInMs: 10)
                let obs3 = store.subscribe(
                    select: { $0.clockSyncState },
                    transform: { "\($0)" }
                )
                // Let them get deallocated immediately
                _ = (obs1, obs2, obs3)
            }
        }

        _ = await dispatchTask.value

        // Give time for any pending async blocks to execute
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // If we reach here without crashing, the test passes
    }

    /// Tests concurrent state updates during observer deallocation does not crash.
    @Test
    func concurrentNewStateCallsDuringDeallocationDoesNotCrash() async throws {
        let store = createStore()
        _ = Context(store)

        let iterations = 30

        for _ in 0..<iterations {
            // Create observer in an autoreleasepool so it gets deallocated quickly
            await withCheckedContinuation { continuation in
                autoreleasepool {
                    let observer = store.subscribeThrottled(select: { $0.clockSyncState }, throttleInMs: 5)

                    // Fire off concurrent state updates
                    Task {
                        await store.setClockSync(.waiting)
                    }
                    Task {
                        await store.setClockSync(.synced)
                    }
                    Task {
                        await store.setClockSync(.waiting)
                    }

                    // Observer will be deallocated when autoreleasepool exits
                    _ = observer
                }

                // Small delay to let async blocks execute
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    continuation.resume()
                }
            }
        }

        // If we reach here without crashing, the test passes
    }
}
