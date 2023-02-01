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
import AnyCodable
import UIKit

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
    case signOut = "sign_out"
    case closeHubViewController = "close_hub_view_controller"
    case triggerSignInWithApple = "trigger_sign_in_with_apple"
    case triggerSignInWithGoogle = "trigger_sign_in_with_google"
    case triggerSignUpWithPasskey = "trigger_sign_up_with_passkey"
    case userDataUpdate = "user_data_update"
    case tryAgain = "try_again"
    case hubLoaded = "hub_loaded"
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
    case userDataUpdate(UserDataUpdateMessage)
    case signOut
    case closeHubViewController
    case unknown
    case triggerSignInWithApple(TriggerSignInWithAppleMessage)
    case triggerSignInWithGoogle(TriggerSignInWithGoogleMessage)
    case triggerSignUpWithPasskey
    case hubLoaded
    case tryAgain
    
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
        case .triggerSignInWithApple:
            let payload = try objectContainer.decode(TriggerSignInWithAppleMessage.self)
            self = .triggerSignInWithApple(payload)
        
        case .triggerSignInWithGoogle:
            let payload = try objectContainer.decode(TriggerSignInWithGoogleMessage.self)
            self = .triggerSignInWithGoogle(payload)
        
        case .triggerSignUpWithPasskey:
            self = .triggerSignUpWithPasskey
            
        case .authentication:
            let payload = try objectContainer.decode(AuthenticationMessage.self)
            self = .authentication(payload)
        
        case .closeHubViewController:
            self = .closeHubViewController
            
        case .userDataUpdate:
            let payload = try objectContainer.decode(UserDataUpdateMessage.self)
            self = .userDataUpdate(payload)
            
        case .signOut:
            self = .signOut
        
        case .tryAgain:
            self = .tryAgain
            
        case .hubLoaded:
            self = .hubLoaded
            
        case .unknown:
            self = .unknown
        }
    }

    public struct AuthenticationMessage: Codable {
        var accessToken: String
        var refreshToken: String
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }
    
    public struct TriggerSignInWithGoogleMessage: Codable {
        var intent: RowndSignInIntent? = nil
        
        enum CodingKeys: String, CodingKey {
            case intent
        }
    }
    
    public struct TriggerSignInWithAppleMessage: Codable {
        var intent: RowndSignInIntent? = nil
        
        enum CodingKeys: String, CodingKey {
            case intent
        }
    }
    
    public struct UserDataUpdateMessage: Codable {
        var data: Dictionary<String, AnyCodable>
        
        enum CodingKeys: String, CodingKey {
            case data = "data"
        }
    }
}

class MessageTypeHolder {
    var type: MessageType?
}

extension CodingUserInfoKey {
    static let messageType = CodingUserInfoKey(rawValue: "ThisMessageType")!
}
