//
//  File.swift
//  
//
//  Created by Michael Murray on 9/5/23.
//

import Foundation
import Get

internal enum ConnectionActionType: String {
    case firebaseToken = "firebase-auth.get-firebase-token"
}

enum ConnectionActionError: Error {
    case customMessage(String)
}

internal struct ConnectionActionPayload: Encodable {
    public var actionType: String

    enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
    }
}

class ConnectionAction {
    internal func getFirebaseIdToken() async throws -> String {
        if (!store.state.auth.isAuthenticated) {
            throw ConnectionActionError.customMessage("User needs to be authenticated to generate a firebase *ID token*")
        }
        do {
            let body = ConnectionActionPayload(actionType: ConnectionActionType.firebaseToken.rawValue)
            let actionResponse: FirebaseGetIdTokenResponse = try await Rownd.apiClient.send(
                Get.Request(
                    url: URL(string: "/hub/connection_action")!,
                    method: "post",
                    body: body,
                    headers: [
                        "content-type":"application/json"
                    ]
                )
            ).value
            
            return actionResponse.data.token
        } catch {
           throw error
        }
    }
}

internal struct FirebaseGetIdTokenResponse: Hashable, Codable {
    public var result: String
    public var data: FirebaseGetIdTokenResponseData

    enum CodingKeys: String, CodingKey {
        case result, data
    }
}

internal struct FirebaseGetIdTokenResponseData: Hashable, Codable {
    public var token: String

    enum CodingKeys: String, CodingKey {
        case token
    }
}


