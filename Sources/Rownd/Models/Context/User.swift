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
    public var data: [String: AnyCodable] = [:]
    public var meta: [String: AnyCodable]? = [:]
}

extension UserState: Codable {
    public enum CodingKeys: String, CodingKey {
        case data, meta
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

    public func set(data: [String: AnyCodable]) {
        DispatchQueue.main.async {
            Context.currentContext.store.dispatch(UserData.save(data))
        }
    }

    public func set(field: String, value: AnyCodable) {
        var userData = self.data
        userData[field] = value
        DispatchQueue.main.async {
            Context.currentContext.store.dispatch(UserData.save(userData))
        }
    }

    internal func setMetaData(_ meta: [String: AnyCodable]) {
        DispatchQueue.main.async {
            Context.currentContext.store.dispatch(UserData.saveMetaData(meta))
        }
    }

    internal func setMetaData(field: String, value: AnyCodable) {
        var meta = self.meta ?? [:]
        meta[field] = value
        DispatchQueue.main.async {
            Context.currentContext.store.dispatch(UserData.saveMetaData(meta))
        }
    }
}

struct SetUserState: Action {
    public var payload = UserState()
}

struct SetUserLoading: Action {
    var isLoading: Bool
}

struct SetUserData: Action {
    var data: [String: AnyCodable] = [:]
    var meta: [String: AnyCodable]? = [:]
}

struct SetUserError: Action {
    var isErrored: Bool = true
    var errorMessage: String
}

func userReducer(action: Action, state: UserState?) -> UserState {
    var state = state ?? UserState()

    switch action {
    case let action as SetUserData:
        state.data = action.data
        state.meta = action.meta ?? [:]
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
    var data: [String: AnyCodable]
}

struct UserMetaDataPayload: Codable {
    var meta: [String: AnyCodable]
}

public struct UserMetaDataResponse: Hashable {
    public var id: String = ""
    public var meta: [String: AnyCodable] = [:]
}

extension UserMetaDataResponse: Codable {
    public enum CodingKeys: String, CodingKey {
        case id, meta
    }
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
                        dispatch(SetUserData(data: user?.data ?? [:], meta: user?.meta ?? [:]))
                    }
                } catch {
                    logger.error("Failed to retrieve user: \(String(describing: error))")

                    // If the user doesn't exist, sign out (user may have been deleted)
                    if case .unacceptableStatusCode(let statusCode) = error as? APIError, statusCode == 404 {
                        logger.warning("This user was not found (likely deleted), so they will be signed out.")
                        Rownd.signOut()
                    }

                }
            }
        }
    }

    static func save() -> Thunk<RowndState> {
        return save(Context.currentContext.store.state.user.data)
    }

    static func save(_ data: [String: AnyCodable]) -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard !state.user.isLoading else { return }

            DispatchQueue.main.async {
                dispatch(SetUserData(data: data, meta: state.user.meta))
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

                let userDataPayload = UserDataPayload(data: data)

                do {
                    let user = try await Rownd.apiClient.send(Request<UserState?>(
                        path: "/me/applications/\(state.appConfig.id ?? "unknown")/data",
                        method: .put,
                        body: userDataPayload
                    )).value

                    logger.debug("Decoded user response: \(String(describing: user))")

                    DispatchQueue.main.async {
                        dispatch(SetUserData(data: user?.data ?? [:], meta: state.user.meta))
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

    static func saveMetaData(_ meta: [String: AnyCodable]) -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard !state.user.isLoading else { return }

            DispatchQueue.main.async {
                dispatch(SetUserData(data: state.user.data, meta: meta))
            }

            Task {
                guard state.auth.isAuthenticated else {
                    return
                }

                do {
                    let response = try await Rownd.apiClient.send(Request<UserMetaDataResponse?>(
                        path: "/me/meta",
                        method: .put,
                        body: UserMetaDataPayload(meta: meta)
                    )).value

                    logger.debug("Saved Rownd meta data: \(String(describing: response))")
                } catch {
                    logger.error("Failed to save meta data: \(String(describing: error))")
                }
            }
        }
    }
}
