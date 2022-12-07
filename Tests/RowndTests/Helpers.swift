//
//  Helpers.swift
//  RowndTests
//
//  Created by Matt Hamann on 11/10/22.
//

import Foundation
import Get
import Mocker

extension APIClient {
    static func mock(_ configure: (inout APIClient.Configuration) -> Void = { _ in }) -> APIClient {
        APIClient(baseURL: URL(string: "https://api.rownd.io")) {
            $0.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
            $0.sessionConfiguration.urlCache = nil
            configure(&$0)
        }
    }
}
