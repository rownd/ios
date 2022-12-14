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
import Get

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

class UserData {
    static func onReceiveUserData(_ newUserState: UserState) -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let _ = getState() else { return }

            dispatch(SetUserState(payload: newUserState))
        }
    }
    
    static func fetch() -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard !state.user.isLoading else { return }
            
            Task {
                guard state.auth.isAuthenticated else {
                    return
                }

                DispatchQueue.main.async {
                    dispatch(SetUserLoading(isLoading: true))
                }
                
                defer {
                    DispatchQueue.main.async {
                        dispatch(SetUserLoading(isLoading: false))
                    }
                }
                
                do {
                    let user = try await Rownd.apiClient.send(Request<UserState?>(path: "/me/applications/\(state.appConfig.id ?? "unknown")/data", method: .get)).value
                    
                    logger.debug("Decoded user response: \(String(describing: user))")

                    DispatchQueue.main.async {
                        dispatch(SetUserData(payload: user?.dataAsDecrypted() ?? [:]))
                    }
                } catch {
                    logger.error("Failed to retrieve user: \(String(describing: error))")
                    
                    // If the user doesn't exist, sign out (user may have been deleted)
                    if case .unacceptableStatusCode(let statusCode) = error as? APIError, statusCode == 404 {
                        Rownd.signOut()
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
            
            Task {
                guard state.auth.isAuthenticated else {
                    return
                }

                DispatchQueue.main.async {
                    dispatch(SetUserLoading(isLoading: true))
                }
                
                defer {
                    DispatchQueue.main.async {
                        dispatch(SetUserLoading(isLoading: false))
                    }
                }

                // Handle data that should be encrypted
                var updatedUserState = UserState()
                updatedUserState.data = data
                
                let userDataPayload = UserDataPayload(data: updatedUserState.dataAsEncrypted())
                
                do {
                    let user = try await Rownd.apiClient.send(Request<UserState?>(
                        path: "/me/applications/\(state.appConfig.id ?? "unknown")/data",
                        method: .put,
                        body: userDataPayload
                    )).value
                    
                    logger.debug("Decoded user response: \(String(describing: user))")
                    
                    DispatchQueue.main.async {
                        dispatch(SetUserData(payload: user?.dataAsDecrypted() ?? [:]))
                    }
                } catch {
                    logger.error("Failed to save user profile: \(String(describing: error))")
                    DispatchQueue.main.async {
                        dispatch(SetUserError(errorMessage: "The user profile could not be saved: \(String(describing: error))"))
                    }
                }
            }
        }
    }
}
