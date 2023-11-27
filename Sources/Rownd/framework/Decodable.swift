//
//  Decodable.swift
//  Rownd
//
//  Created by Bobby Radford on 11/3/23.
//

import Foundation

extension Decodable {
    static func fromJson(message: String) throws -> Self {
        let decoder = JSONDecoder()
        decoder.userInfo[.messageType] = MessageTypeHolder()
        let result = try decoder.decode(Self.self, from: message.data(using: .utf8)!)
        return result
    }
}
