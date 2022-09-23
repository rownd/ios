//
//  Auth.swift
//  framework
//
//  Created by Matt Hamann on 7/8/22.
//

import Foundation
import UIKit
import ReSwift
import ReSwiftThunk
import AnyCodable

public struct UserState: Hashable {
    public var isLoading: Bool = false
    public var isErrored: Bool = false
    public var errorMessage: String?
    public var data: Dictionary<String, AnyCodable> = [:]
    public var redacted: [String]?
}

extension UserState: Codable {
    public enum CodingKeys: String, CodingKey {
        case data, redacted
    }

    public func get() -> UserState {
        return self
    }

    public func get(field: String) -> Any {
        return self.data[field] ?? nil
    }

    public func get<T>(field: String) -> T? {
        guard let value = self.data[field] else {
            return nil
        }

        return value.value as? T
    }

    public func set(data: Dictionary<String, AnyCodable>) -> Void {
        DispatchQueue.main.async {
            store.dispatch(UserData.save(data))
        }
    }

    public func set(field: String, value: AnyCodable) -> Void {
        var userData = self.data
        userData[field] = value
        DispatchQueue.main.async {
            store.dispatch(UserData.save(userData))
        }
    }

    internal func dataAsEncrypted() -> Dictionary<String, AnyCodable> {
        let encKeyId = Rownd.user.ensureEncryptionKey(user: self)

        var data: Dictionary<String, AnyCodable> = [:].merging(self.data) { (current, _) in current }

        if let encKeyId = encKeyId {
            // Decrypt user fields
            for (key, value) in data {
                if store.state.appConfig.schema?[key]?.encryption?.state == .enabled, let value = value.value as? String {
                    do {
                        let encrypted: String = try RowndEncryption.encrypt(plaintext: value, withKeyId: encKeyId)
                        data[key] = AnyCodable.init(encrypted)
                    } catch {
                        logger.trace("Failed to encrypt user data value. Error: \(String(describing: error))")
                    }
                }
            }
        }

        return data
    }

    internal func dataAsDecrypted() -> Dictionary<String, AnyCodable> {
        let encKeyId = Rownd.user.ensureEncryptionKey(user: self)

        var data: Dictionary<String, AnyCodable> = [:].merging(self.data) { (current, _) in current }

        if let encKeyId = encKeyId {
            // Decrypt user fields
            for (key, value) in data {
                if store.state.appConfig.schema?[key]?.encryption?.state == .enabled, let value = value.value as? String {
                    do {
                        let decrypted: String = try RowndEncryption.decrypt(ciphertext: value, withKeyId: encKeyId)
                        data[key] = AnyCodable.init(decrypted)
                    } catch {
                        logger.trace("Failed to decrypt user data value. Error: \(String(describing: error))")
                    }
                }
            }
        }

        return data
    }
}

struct SetUserState: Action {
    public var payload = UserState()
}

struct SetUserLoading: Action {
    var isLoading: Bool
}

struct SetUserData: Action {
    var payload: Dictionary<String, AnyCodable> = [:]
}

struct SetUserError: Action {
    var isErrored: Bool = true
    var errorMessage: String
}

func userReducer(action: Action, state: UserState?) -> UserState {
    var state = state ?? UserState()
    
    switch action {
    case let action as SetUserData:
        state.data = action.payload
    case let action as SetUserLoading:
        state.isLoading = action.isLoading
    case let action as SetUserState:
        state = action.payload
    default:
        break
    }
    
    return state
}

/* API / side-effecty things */

// Easily unwrap the main payload from the `app` key
struct UserDataPayload: Codable {
    var data: Dictionary<String, AnyCodable>
    var redacted: [String]?
}

struct UserDataResource: APIResource {
    typealias ModelType = UserState
    
    var methodPath: String {
        guard let appId = store.state.appConfig.id else { return "/me/applications/unknown/data" }
        return "/me/applications/\(appId)/data"
    }
    
    var headers: Dictionary<String, String>? = Dictionary<String, String>()
}

class UserData {
    //    private var req: APIRequest<AppConfigResource>?
    
    static func fetch() -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard !state.user.isLoading else { return }
            
            Task.init {
                guard let accessToken = await Rownd.getAccessToken() else {
                    return
                }

                DispatchQueue.main.async {
                    dispatch(SetUserLoading(isLoading: true))
                }
                var resource = UserDataResource()
                resource.headers = ["Authorization": "Bearer \(accessToken)"]
                let request = APIRequest(resource: resource)
                
                request.execute { userResp in
                    // This guard ensures that the resource allocator doesn't clean up the request object before
                    // the parsing closure in request.execute() is finished with it.
                    guard request.decode != nil else {
                        DispatchQueue.main.async {
                            dispatch(SetUserLoading(isLoading: false))
                        }
                        return
                    }
                    logger.debug("Decoded user response: \(String(describing: userResp))")

                    DispatchQueue.main.async {
                        dispatch(SetUserLoading(isLoading: false))
                        dispatch(SetUserData(payload: userResp?.dataAsDecrypted() ?? [:]))
                    }
                }
            }
        }
    }
    
    static func save() -> Thunk<RowndState> {
        return save(store.state.user.data)
    }
    
    static func save(_ data: Dictionary<String, AnyCodable>) -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard !state.user.isLoading else { return }

            DispatchQueue.main.async {
                dispatch(SetUserData(payload: data))
            }
            
            Task.init {
                guard let accessToken = await Rownd.getAccessToken() else {
                    return
                }

                DispatchQueue.main.async {
                    dispatch(SetUserLoading(isLoading: true))
                }
                var resource = UserDataResource()
                resource.headers = [
                    "Authorization": "Bearer \(accessToken)",
                    "Content-Type": "application/json"
                ]
                let request = APIRequest(resource: resource)

                // Handle data that should be encrypted
                var updatedUserState = UserState()
                updatedUserState.data = data
                
                // TODO: Do we need to current user state as json string for body and merge?
                let encoder = JSONEncoder()
                let userDataPayload = UserDataPayload(data: updatedUserState.dataAsEncrypted())

                var body: Data? = nil
                do {
                    body = try encoder.encode(userDataPayload)
                } catch {
                    DispatchQueue.main.async {
                        dispatch(SetUserError(errorMessage: "The user profile could not be encoded: \(error)"))
                    }
                }
                request.execute(method: "PUT", body: body) { userResp in
                    // This guard ensures that the resource allocator doesn't clean up the request object before
                    // the parsing closure in request.execute() is finished with it.
                    guard request.decode != nil else { return }
                    logger.debug("Decoded user response: \(String(describing: userResp))")

                    DispatchQueue.main.async {
                        dispatch(SetUserData(payload: userResp?.dataAsDecrypted() ?? [:]))
                        dispatch(SetUserLoading(isLoading: false))
                    }
                }
            }
        }
    }
}
