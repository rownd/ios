//
//  RowndHubInteropMessage.swift
//  ios native
//
//  Created by Matt Hamann on 6/14/22.
//

/*
 This structure relies on userData within the decodable in order to reference a parent value.
 Here's an example of how to use it:
 let jsonData = """
 {
     "type": "authentication",
     "payload": {
         "access_token": "foo",
         "refresh_token": "bar"
     }
 }
 """.data(using: .utf8)

 let decoder = JSONDecoder()
 decoder.userInfo[.messageType] = MessageTypeHolder()
 let result = try decoder.decode(RowndHubInteropMessage.self, from: jsonData!)
 print(result)

 */

import Foundation

struct RowndHubInteropMessage: Decodable {
    var type: MessageType
    var payload: MessagePayload?
    
    static func fromJson(message: String) throws -> RowndHubInteropMessage {
        let decoder = JSONDecoder()
        decoder.userInfo[.messageType] = MessageTypeHolder()
        let result = try decoder.decode(RowndHubInteropMessage.self, from: message.data(using: .utf8)!)
        return result
    }
}

enum MessageType: String, Codable {
    case authentication
    case unknown

    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let type = try container.decode(String.self)
        self = MessageType(rawValue: type) ?? .unknown

        if let messageType = decoder.userInfo[.messageType] as? MessageTypeHolder {
            messageType.type = self
        }
    }
}

enum MessagePayload: Decodable {
    case authentication(AuthenticationMessage)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        // We're accessing a value from the parent that must exist, else we can't continue
        guard let messageType = decoder.userInfo[.messageType] as? MessageTypeHolder else {
            self = .unknown
            return;
        }
        let type = messageType.type!
        
        let objectContainer = try decoder.singleValueContainer()
        
        switch type {
        case .authentication:
            let payload = try objectContainer.decode(AuthenticationMessage.self)
            self = .authentication(payload)
            
        case .unknown:
            self = .unknown
        }
    }
    
    struct AuthenticationMessage: Codable {
        var accessToken: String
        var refreshToken: String
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }
}

class MessageTypeHolder {
    var type: MessageType?
}

extension CodingUserInfoKey {
    static let messageType = CodingUserInfoKey(rawValue: "ThisMessageType")!
}
