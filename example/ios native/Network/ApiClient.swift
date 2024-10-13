//
//  ApiClient.swift
//  rownd_ios_example
//
//  Created by Matt Hamann on 3/25/24.
//

import Foundation
import Get
import AnyCodable
import Rownd
import UIKit

let client = APIClient(baseURL: URL(string: "https://5b24-99-37-55-241.ngrok-free.app"))

struct TokenExchangeBody: Serializable {
    let idToken: String
}

struct TokenResp: Serializable {
    let message: String
    let tokenObj: AnyCodable?
}

func apiExchangeRowndToken(body: TokenExchangeBody) async throws -> TokenResp {
    do {
        let formatter = ISO8601DateFormatter()
        let currentDate = Date()
        let dateSource = "local"

        let userAgentStr = "Rownd SDK for iOS/\(String(describing: Bundle.main.bundleIdentifier)) (Language: Swift; Platform=\(await UIDevice.current.systemName) \(ProcessInfo.processInfo.operatingSystemVersionString); Timestamp=\(currentDate.ISO8601Format()); Timezone=\(TimeZone.current); TimeSource=\(dateSource)"

        let request = Request<TokenResp>(path: "/token", method: .post, body: body, headers: ["User-Agent": userAgentStr])
        let resp: TokenResp = try await client.send(request).value
        return resp
    } catch {
        throw error
    }
}
