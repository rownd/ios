//
//  Encodable+AsJSONString.swift
//  RowndSDK
//
//  Created by Matt Hamann on 7/13/22.
//

import Foundation
import AnyCodable

extension Encodable {
    func asJsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }
    
    func isString() -> String? {
        if let string = self as? String {
            return string
        }
        return nil
    }
}
