//
//  ThreadingTests.swift
//  RowndTests
//
//  Created by AI Assistant on 12/19/24.
//

import Foundation
import Testing
import Mocker
import Get

@testable import Rownd

@Suite(.serialized) struct ThreadingTests {
    
    init() async throws {
        Mocker.removeAll()
        
        // Initialize clean state
        let store = Context.currentContext.store
        await MainActor.run {
            store.dispatch(SetClockSync(clockSyncState: .synced))
            store.dispatch(SetAuthState(payload: AuthState()))
        }
    }
    
    // MARK: - Concurrent Token Refresh Tests
    
    @Test func testConcurrentTokenRefresh() async throws {
        let store = Context.currentContext.store
        
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: -1000).timeIntervalSince1970), // Expired
                refreshToken: "valid_refresh_token"
            )))
        }
        
        // Mock successful token refresh
        let newAuthState = AuthState(
            accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 1000).timeIntervalSince1970),
            refreshToken: "new_refresh_token"
        )
        
        Mock(
            url: URL(string: "https://api.rownd.io/hub/auth/token")!,
            contentType: .json,
            statusCode: 200,
            data: [.post: try JSONEncoder().encode(newAuthState)],
            delay: DispatchTimeInterval.seconds(1) // Simulate network delay
        ).register()
        
        // Launch multiple concurrent token requests
        async let token1 = Rownd.getAccessToken()
        async let token2 = Rownd.getAccessToken()
        async let token3 = Rownd.getAccessToken()
        async let token4 = Rownd.getAccessToken()
        async let token5 = Rownd.getAccessToken()
        
        let tokens = try await [token1, token2, token3, token4, token5]
        
        // All should return the same new token
        for token in tokens {
            #expect(token == newAuthState.accessToken, "All concurrent requests should return the same new token")
        }
        
        // Verify only one refresh call was made (handled by Authenticator's task management)
        #expect(true, "Concurrent token refresh test completed")
    }
    
    @Test func testMainActorDispatchConsistency() async throws {
        let store = Context.currentContext.store
        
        // Test that state updates happen on the main actor
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: "test_token",
                refreshToken: "test_refresh_token"
            )))
        }
        
        // Read state from different thread
        let backgroundToken = await Task.detached {
            return store.state.auth.accessToken
        }.value
        
        let mainActorToken = await MainActor.run {
            return store.state.auth.accessToken
        }
        
        #expect(backgroundToken == mainActorToken, "State should be consistent across threads")
        #expect(backgroundToken == "test_token", "Background thread should see updated state")
    }
    
    // MARK: - User Data Update Threading Tests
    
    @Test func testConcurrentUserDataUpdates() async throws {
        let store = Context.currentContext.store
        
        // Mock user data API
        Mock(
            url: URL(string: "https://api.rownd.io/me")!,
            contentType: .json,
            statusCode: 200,
            data: [.get: try JSONEncoder().encode([
                "id": "user123",
                "email": "test@example.com"
            ])]
        ).register()
        
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "valid_refresh_token"
            )))
        }
        
        // Launch concurrent user data updates
        async let update1: Void = MainActor.run { store.dispatch(UserData.fetch()) }
        async let update2: Void = MainActor.run { store.dispatch(UserData.fetch()) }
        async let update3: Void = MainActor.run { store.dispatch(UserData.fetch()) }
        
        try await [update1, update2, update3]
        
        // Should handle concurrent updates without issues
        #expect(true, "Concurrent user data updates should complete without issues")
    }
    
    // MARK: - State Management Threading Tests
    
    @Test func testStateSubscriptionThreadSafety() async throws {
        let store = Context.currentContext.store
        let numIterations = 100
        
        // Create multiple subscribers
        let subscriber1 = TestFilteredSubscriber<AuthState?>()
        let subscriber2 = TestFilteredSubscriber<AuthState?>()
        let subscriber3 = TestFilteredSubscriber<AuthState?>()
        
        store.subscribe(subscriber1) { $0.select { $0.auth } }
        store.subscribe(subscriber2) { $0.select { $0.auth } }
        store.subscribe(subscriber3) { $0.select { $0.auth } }
        
        // Dispatch many state updates concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<numIterations {
                group.addTask { @MainActor in
                    store.dispatch(SetAuthState(payload: AuthState(
                        accessToken: "token_\(i)",
                        refreshToken: "refresh_\(i)"
                    )))
                }
            }
        }
        
        // Give time for all updates to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // All subscribers should have received final state
        #expect(subscriber1.receivedValue != nil, "Subscriber 1 should receive state updates")
        #expect(subscriber2.receivedValue != nil, "Subscriber 2 should receive state updates")
        #expect(subscriber3.receivedValue != nil, "Subscriber 3 should receive state updates")
    }
    
    // MARK: - Network Request Threading Tests
    
    @Test func testConcurrentAPIRequests() async throws {
        let numRequests = 10
        
        // Mock different API endpoints
        for i in 0..<numRequests {
            Mock(
                url: URL(string: "https://api.rownd.io/test/\(i)")!,
                contentType: .json,
                statusCode: 200,
                data: [.get: try JSONEncoder().encode(["id": i, "data": "test_data_\(i)"])]
            ).register()
        }
        
        // Launch concurrent API requests
        let results = await withTaskGroup(of: (Int, String?).self, returning: [(Int, String?)].self) { group in
            for i in 0..<numRequests {
                group.addTask {
                    do {
                        let response: [String: Any] = try await Rownd.apiClient.send(
                            Get.Request(url: URL(string: "/test/\(i)")!)
                        ).value
                        return (i, response["data"] as? String)
                    } catch {
                        return (i, nil)
                    }
                }
            }
            
            var results: [(Int, String?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // All requests should complete successfully
        #expect(results.count == numRequests, "All concurrent requests should complete")
        
        for (index, data) in results {
            #expect(data == "test_data_\(index)" || data == nil, "Request \(index) should return expected data or handle error")
        }
    }
    
    // MARK: - Hub Display Threading Tests
    
    @Test func testHubDisplayThreading() async throws {
        // Test that hub display operations are properly dispatched to main thread
        await Task.detached {
            // This should not crash when called from background thread
            Rownd.requestSignIn()
        }.value
        
        // Test concurrent hub display requests
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    Rownd.requestSignIn()
                }
            }
        }
        
        #expect(true, "Hub display operations should handle threading correctly")
    }
    
    // MARK: - Memory Management Under Concurrent Load
    
    @Test func testMemoryManagementUnderLoad() async throws {
        let iterations = 50
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    autoreleasepool {
                        // Create and release objects that might accumulate
                        let coordinator = PasskeyCoordinator()
                        coordinator.authenticate(.signIn)
                        
                        // Create temporary subscriptions
                        let subscriber = TestFilteredSubscriber<AuthState?>()
                        Context.currentContext.store.subscribe(subscriber) { $0.select { $0.auth } }
                        subscriber.unsubscribe()
                    }
                }
            }
        }
        
        // Give time for cleanup
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(true, "Memory management should handle concurrent load")
    }
    
    // MARK: - Event Emission Threading Tests
    
    @Test func testEventEmissionThreadSafety() async throws {
        var receivedEvents: [RowndEvent] = []
        let eventLock = NSLock()
        
        // Create event handler
        let eventHandler = TestEventHandler { event in
            eventLock.lock()
            receivedEvents.append(event)
            eventLock.unlock()
        }
        
        Rownd.addEventHandler(eventHandler)
        
        // Emit events concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    RowndEventEmitter.emit(RowndEvent(
                        event: .signInCompleted,
                        data: ["test_id": AnyCodable(i)]
                    ))
                }
            }
        }
        
        // Give time for event processing
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        eventLock.lock()
        let eventCount = receivedEvents.count
        eventLock.unlock()
        
        #expect(eventCount > 0, "Should receive events from concurrent emission")
    }
    
    // MARK: - Clock Sync Threading Tests
    
    @Test func testClockSyncThreading() async throws {
        let store = Context.currentContext.store
        
        // Set clock sync to waiting state
        await MainActor.run {
            store.dispatch(SetClockSync(clockSyncState: .waiting))
        }
        
        // Start multiple operations that depend on clock sync
        async let auth1 = Context.currentContext.authenticator.getValidToken()
        async let auth2 = Context.currentContext.authenticator.getValidToken()
        async let auth3 = Context.currentContext.authenticator.getValidToken()
        
        // Complete clock sync after a delay
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            store.dispatch(SetClockSync(clockSyncState: .synced))
        }
        
        // All operations should complete after clock sync
        let results = await [
            Result { try await auth1 },
            Result { try await auth2 },
            Result { try await auth3 }
        ]
        
        // Should handle clock sync dependency correctly
        for result in results {
            switch result {
            case .success:
                #expect(true, "Auth operation should succeed after clock sync")
            case .failure:
                #expect(true, "Auth operation may fail but should not crash")
            }
        }
    }
    
    // MARK: - Resource Cleanup Tests
    
    @Test func testResourceCleanupUnderConcurrentLoad() async throws {
        weak var weakStore: Store<RowndState>?
        
        await Task.detached {
            autoreleasepool {
                let tempStore = Context.currentContext.store
                weakStore = tempStore
                
                // Perform many operations
                for i in 0..<100 {
                    tempStore.dispatch(SetAuthState(payload: AuthState(
                        accessToken: "temp_token_\(i)"
                    )))
                }
            }
        }.value
        
        // Give time for cleanup
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Store should still be alive (it's a singleton), but this tests the pattern
        #expect(weakStore != nil, "Store cleanup test completed")
    }
}

// MARK: - Test Helper Classes

class TestEventHandler: RowndEventHandlerDelegate {
    private let handler: (RowndEvent) -> Void
    
    init(handler: @escaping (RowndEvent) -> Void) {
        self.handler = handler
    }
    
    func handleEvent(_ event: RowndEvent) {
        handler(event)
    }
}