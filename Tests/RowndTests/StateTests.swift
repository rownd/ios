//
//  StateTests.swift
//
//
//  Created by Matt Hamann on 4/1/24.
//

import Combine
import Foundation
import XCTest

@testable import Rownd

class StateTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func testStateInit() async throws {
        let store = createStore()
        XCTAssertFalse(store.state.isStateLoaded)
        await store.load()
        try await Task.sleep(nanoseconds: 10000)
        XCTAssertTrue(store.state.isStateLoaded)
    }

    func testMultiStepInit() async throws {
        let expectation = XCTestExpectation(description: "Wait for state to initialize")
        let context = Context.currentContext
        let store = context.store

        var rootStateValues: [RowndState] = []
        var authStateValues: [AuthState] = []
        var cancellables = Set<AnyCancellable>()

        store.publisher()
            .sink { state in
                rootStateValues.append(state)
            }
            .store(in: &cancellables)

        store.publisher(for: \.auth)
            .sink { auth in
                authStateValues.append(auth)
            }
            .store(in: &cancellables)

        await store.load()
        await store.setAuth(AuthState(
            accessToken: generateJwt(expires: Date.init(timeIntervalSinceNow: 3600).timeIntervalSince1970),
            refreshToken: generateJwt(expires: Date.init(timeIntervalSinceNow: 36000).timeIntervalSince1970)
        ))
        await store.setClockSync(.synced)

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        XCTAssertTrue(rootStateValues.last?.isInitialized == true)
        XCTAssertTrue(authStateValues.last?.isAccessTokenValid == true)
        expectation.fulfill()

        await fulfillment(of: [expectation], timeout: 10.0)
    }
}
