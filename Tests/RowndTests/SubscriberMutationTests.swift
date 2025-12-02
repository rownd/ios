import Combine
import Foundation
import Testing

@testable import Rownd

struct SubscriberMutationTests {
    @Test
    func rapidClockSyncAndObserverChurnDoesNotCrash() async throws {
        let store = Context.currentContext.store

        // Ensure starting state
        await store.load()

        let iterations = 50

        // Flip clockSyncState quickly
        let flipTask = Task {
            for i in 0..<iterations {
                let state: ClockSyncState = (i % 2 == 0) ? .waiting : .synced
                await store.setClockSync(state)
            }
        }

        // Create and drop observable subscribers rapidly (subscribe/unsubscribe)
        for _ in 0..<iterations {
            autoreleasepool {
                let obs = store.subscribe(select: { $0.clockSyncState })
                _ = obs  // keep alive within loop scope
            }
        }

        _ = await flipTask.value
        // If we reached here without a crash, we consider it a pass.
    }
}
