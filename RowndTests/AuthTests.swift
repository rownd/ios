//
//  AuthTests.swift
//  RowndTests
//
//  Created by Matt Hamann on 9/21/22.
//

import Foundation
import Mocker
import CryptoKit

import XCTest
@testable import Rownd

class AuthTests: XCTestCase {

    func testRefreshToken() throws {
        store.dispatch(SetAuthState(payload: AuthState(
            accessToken: generateJwt(expires: NSDate().timeIntervalSince1970), // this will be expired
            refreshToken: "eyJhbGciOiJFZERTQSIsImtpZCI6InNpZy0xNjQ0OTM3MzYwIn0.eyJqdGkiOiJiNzY4NmUxNC0zYjk2LTQzMTItOWM3ZS1iODdmOTlmYTAxMzIiLCJhdWQiOlsiYXBwOjMzNzA4MDg0OTIyMTU1MDY3MSJdLCJzdWIiOiJnb29nbGUtb2F1dGgyfDExNDg5NTEyMjc5NTQ1MjEyNzI3NiIsImh0dHBzOi8vYXV0aC5yb3duZC5pby9hcHBfdXNlcl9pZCI6ImM5YTgxMDM5LTBjYmMtNDFkNy05YTlkLWVhOWI1YTE5Y2JmMCIsImh0dHBzOi8vYXV0aC5yb3duZC5pby9pc192ZXJpZmllZF91c2VyIjp0cnVlLCJpc3MiOiJodHRwczovL2FwaS5yb3duZC5pbyIsImlhdCI6MTY2NTk3MTk0MiwiaHR0cHM6Ly9hdXRoLnJvd25kLmlvL2p3dF90eXBlIjoicmVmcmVzaF90b2tlbiIsImV4cCI6MTY2ODU2Mzk0Mn0.Yn35j83bfFNgNk26gTvd4a2a2NAGXp7eknvOaFAtd3lWCdvtw6gKRso6Uzd7uydy2MWJFRWC38AkV6lMMfnrDw"
        )))

        let mock = Mock(
            url: URL(string: "https://api.rownd.io/hub/auth/token")!,
            ignoreQuery: true,
            dataType: .json,
            statusCode: 200,
            data: [
                .post : try! Data(contentsOf: MockedData.refreshTokenResponse)
            ]
        )
        mock.register()

        let expectation = self.expectation(description: "Refreshing token")
        Task {
            let authState = try! await Rownd.authenticator.refreshToken()

            XCTAssertNotNil(authState, "Returned resource should not be nil")
            XCTAssertNotNil(authState.accessToken, "Access token should be present")

            expectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }

    func testMultipleAuthenticatedReqeustsWithExpiredAccessToken() throws {
        store.dispatch(SetAuthState(payload: AuthState(
            accessToken: generateJwt(expires: NSDate().timeIntervalSince1970), // this will be expired
            refreshToken: "eyJhbGciOiJFZERTQSIsImtpZCI6InNpZy0xNjQ0OTM3MzYwIn0.eyJqdGkiOiJiNzY4NmUxNC0zYjk2LTQzMTItOWM3ZS1iODdmOTlmYTAxMzIiLCJhdWQiOlsiYXBwOjMzNzA4MDg0OTIyMTU1MDY3MSJdLCJzdWIiOiJnb29nbGUtb2F1dGgyfDExNDg5NTEyMjc5NTQ1MjEyNzI3NiIsImh0dHBzOi8vYXV0aC5yb3duZC5pby9hcHBfdXNlcl9pZCI6ImM5YTgxMDM5LTBjYmMtNDFkNy05YTlkLWVhOWI1YTE5Y2JmMCIsImh0dHBzOi8vYXV0aC5yb3duZC5pby9pc192ZXJpZmllZF91c2VyIjp0cnVlLCJpc3MiOiJodHRwczovL2FwaS5yb3duZC5pbyIsImlhdCI6MTY2NTk3MTk0MiwiaHR0cHM6Ly9hdXRoLnJvd25kLmlvL2p3dF90eXBlIjoicmVmcmVzaF90b2tlbiIsImV4cCI6MTY2ODU2Mzk0Mn0.Yn35j83bfFNgNk26gTvd4a2a2NAGXp7eknvOaFAtd3lWCdvtw6gKRso6Uzd7uydy2MWJFRWC38AkV6lMMfnrDw"
        )))

        let responseData = AuthState(
            accessToken: generateJwt(expires: Date.init(timeIntervalSinceNow: 1000).timeIntervalSince1970),
            refreshToken: generateJwt(expires: Date.init().timeIntervalSince1970)
        )
        print("Response data will be: \(String(describing: responseData))")

        var numTimesRefreshCalled = 0
        var mock = Mock(
            url: URL(string: "https://api.rownd.io/hub/auth/token")!,
            ignoreQuery: true,
            dataType: .json,
            statusCode: 200,
            data: [
                .post : try JSONEncoder().encode(responseData)
            ]
        )

        mock.onRequest = { request, postBodyArguments in
            numTimesRefreshCalled += 1
            print("Refresh called: \(numTimesRefreshCalled) times")
            XCTAssertLessThanOrEqual(numTimesRefreshCalled, 1)
        }

        mock.delay = DispatchTimeInterval.seconds(2)

        mock.register()

        let expectation1 = self.expectation(description: "Refreshing token 1")
        let expectation2 = self.expectation(description: "Refreshing token 2")

        Task {
            let token1 = await Rownd.getAccessToken()
            XCTAssertEqual(token1, responseData.accessToken)

            expectation1.fulfill()
        }

        Task {
            let token2 = await Rownd.getAccessToken()
            XCTAssertEqual(token2, responseData.accessToken)
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }
}

struct Header: Encodable {
    let alg = "HS256"
    let typ = "JWT"
}

struct Payload: Encodable {
    var sub = "1234567890"
    var name = "John Doe"
    var iat = 1516239022
    var exp = Int(Date.init().timeIntervalSince1970)
}

fileprivate func generateJwt(expires: TimeInterval) -> String {
    let secret = "your-256-bit-secret"
    let privateKey = SymmetricKey(data: Data(secret.utf8))

    let headerJSONData = try! JSONEncoder().encode(Header())
    let headerBase64String = headerJSONData.urlSafeBase64EncodedString()

    var payload = Payload()
    payload.exp = Int(expires)
    let payloadJSONData = try! JSONEncoder().encode(Payload())
    let payloadBase64String = payloadJSONData.urlSafeBase64EncodedString()

    let toSign = Data((headerBase64String + "." + payloadBase64String).utf8)

    let signature = HMAC<SHA256>.authenticationCode(for: toSign, using: privateKey)
    let signatureBase64String = Data(signature).urlSafeBase64EncodedString()

    let token = [headerBase64String, payloadBase64String, signatureBase64String].joined(separator: ".")
    return token
}

extension Data {
    func urlSafeBase64EncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
