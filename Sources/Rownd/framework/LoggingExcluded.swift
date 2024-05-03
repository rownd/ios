//
//  LoggingExcluded.swift
//  RowndSDK
//
//  Created by Matt Hamann on 7/12/22.
//

import Foundation

@propertyWrapper
public struct LoggingExcluded<Value>: CustomStringConvertible, CustomDebugStringConvertible, CustomLeafReflectable {

    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public var description: String {
        return "<REDACTED>"
    }

    public var debugDescription: String {
        return "<REDACTED>"
    }

    public var customMirror: Mirror {
        return Mirror(reflecting: "<REDACTED>")
    }
}

extension LoggingExcluded: Decodable where Value: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
    }
}
extension LoggingExcluded: Encodable where Value: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}
