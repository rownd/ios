//
//  RowndApi.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/16/22.
//

import Foundation
import Get

let baseConfig = APIClient.Configuration(
    baseURL: URL(string: Rownd.config.apiUrl),
    delegate: RowndUnauthenticatedApiClientDelegate()
)
let rowndApi = Get.APIClient(configuration: baseConfig)

class RowndUnauthenticatedApiClientDelegate : APIClientDelegate {
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        print("Making a request to \(String(describing: request.url))")
    }
}

class RowndApi {
    let client: APIClient

    init() {
        let config = APIClient.Configuration(baseURL: URL(string: Rownd.config.apiUrl), delegate: RowndApiClientDelegate())
        client = APIClient(configuration: config)
    }
}

class RowndApiClientDelegate : APIClientDelegate {
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        request.setValue(DEFAULT_API_USER_AGENT, forHTTPHeaderField: "User-Agent")
        request.setValue(Rownd.config.appKey, forHTTPHeaderField: "X-Rownd-App-Key")

        if store.state.auth.isAuthenticated, let accessToken = await Rownd.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        var localRequest = request
        logger.debug("Making request to: \(String(describing: localRequest.httpMethod?.uppercased())) \(String(describing: localRequest.url))")
    }
}
