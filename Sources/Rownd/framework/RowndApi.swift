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
    // Pre-request hook
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        request.setValue(DEFAULT_API_USER_AGENT, forHTTPHeaderField: "User-Agent")
        if request.httpMethod?.lowercased() != "get", request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        print("Making a request to \(String(describing: request.url))")
    }
    
    // Post-response validation
    func client(
        _ client: APIClient,
        validateResponse response: HTTPURLResponse,
        data: Data,
        task: URLSessionTask
    ) throws {
        guard (200..<300).contains(response.statusCode) else {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(RowndApiError.self, from: data) {
                throw ApiError.generic(decoded)
            } else {
                throw ApiError.unexpected
            }
        }
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

        do {
            if store.state.auth.isAuthenticated, let accessToken = try await Rownd.getAccessToken() {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        } catch {
            // no-op
        }

        let localRequest = request
        logger.debug("Making request to: \(String(describing: localRequest.httpMethod?.uppercased())) \(String(describing: localRequest.url))")
    }
}

struct RowndApiError : Codable, Hashable {
    var statusCode: Int
    var error: String
    var code: String?
    var messages: [String]
}

extension RowndApiError {
    enum CodingKeys: String, CodingKey {
        case error, code, messages, statusCode
    }
}

enum ApiError : Error {
    case generic(RowndApiError)
    case unexpected
}
