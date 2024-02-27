//
//  Encodable+AsJSONString.swift
//  RowndSDK
//
//  Created by Matt Hamann on 7/13/22.
//

import Foundation

extension Encodable {
    func asJsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }
}
