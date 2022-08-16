//
//  RowndApi.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/16/22.
//

import Foundation
import Get

let rowndApi = Get.APIClient(baseURL: URL(string: Rownd.config.apiUrl))

class RowndApi {
    static let client = Get.APIClient(configuration: APIClient.Configuration(baseURL: URL(string: Rownd.config.apiUrl), delegate: RowndApiClientDelegate()))
}

class RowndApiClientDelegate : APIClientDelegate {
    func client(_ client: APIClient, willSendRequest: inout URLRequest) async throws {

    }
}
