//
//  RowndTests.swift
//  RowndTests
//
//  Created by Matt Hamann on 7/15/22.
//

import Foundation
import Testing
@testable import Rownd

struct RowndTests {

    init() async throws {

    }

    @Test func signOut() async throws {
        let store = Context.currentContext.store

        await store.setAuth(AuthState(
            accessToken: generateJwt(expires: NSDate().timeIntervalSince1970),
            refreshToken: generateJwt(expires: NSDate().timeIntervalSince1970)
        ))

        #expect(store.state.auth.isAuthenticated == true)

        Rownd.signOut()

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        #expect(store.state.auth.isAuthenticated == false)
    }

}
