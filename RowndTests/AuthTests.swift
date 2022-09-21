//
//  AuthTests.swift
//  RowndTests
//
//  Created by Matt Hamann on 9/21/22.
//

import Foundation
import Mocker

import XCTest
@testable import Rownd

class AuthTests: XCTestCase {

    func testRefreshToken() throws {
        print("testBundle.bundlePath = \(Bundle.module.bundlePath)")
        let mock = Mock(url: URL(string: "https://api.rownd.io/hub/auth/token?")!, dataType: .json, statusCode: 200, data: [
            .post : try! Data(contentsOf: MockedData.refreshTokenResponse)
        ])
        mock.register()

        let expectation = self.expectation(description: "Refreshing token")
        var xAuthState: AuthState? = nil
        Auth.fetchToken(refreshToken: "this is a fake refresh token") { authState in
            xAuthState = authState
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)

        XCTAssertNotNil(xAuthState, "Returned resource should not be nil")
        XCTAssertNotNil(xAuthState?.accessToken, "Access token should be present")
    }
}
