//
//  RowndTests.swift
//  RowndTests
//
//  Created by Matt Hamann on 7/15/22.
//

import Testing
@testable import Rownd
import Foundation

struct RowndTests {

    init() async throws {

    }

    @Test func signOut() async throws {
        let store = Context.currentContext.store

        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: NSDate().timeIntervalSince1970),
                refreshToken: generateJwt(expires: NSDate().timeIntervalSince1970)
            )))
        }

        #expect(store.state?.auth.isAuthenticated == true)

        Rownd.signOut()

        await MainActor.run {
            #expect(store.state?.auth.isAuthenticated == false)
        }
    }

}
