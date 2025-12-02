import Foundation
import Testing

@testable import Rownd

struct AutomationsCoordinatorTests {
    @Test
    func startWhileDispatchingDoesNotCrash() async throws {
        // Install a fresh context with a new store to isolate from global state
        let store = createStore()
        _ = Context(store)

        let coordinator = AutomationsCoordinator()
        let iterations = 50

        // Dispatch a flurry of state updates while starting the coordinator
        let dispatchTask = Task {
            for i in 0..<iterations {
                let state: ClockSyncState = (i % 2 == 0) ? .waiting : .synced
                await store.setClockSync(state)
                await store.setUserLoading(i % 3 == 0)
            }
        }

        // Start subscription on main to match production behavior
        let startTask = Task { @MainActor in
            coordinator.start()
        }

        _ = await (dispatchTask.value, startTask.value)
        // If we reached here without a crash, the test passes.
    }
}
