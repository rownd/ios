//
//  User.swift
//  framework
//
//  Created by Matt Hamann on 7/8/22.
//

import AnyCodable
import Foundation
import Get
import OSLog
import UIKit

private let log = Logger(subsystem: "io.rownd.sdk", category: "user")

public typealias UserStateData = [String: AnyCodable]

public enum UserStateVal: String, Codable, Hashable, Sendable {
    case enabled = "enabled"
    case disabled = "disabled"
}

public enum UserAuthLevel: String, Codable, Hashable, Sendable {
    case instant = "instant"
    case guest = "guest"
    case unverified = "unverified"
    case verified = "verified"
    case unknown = "unknown"
}

public struct UserState: Hashable, Sendable {
    public var isLoading: Bool = false
    public var isErrored: Bool = false
    public var errorMessage: String?
    public var data: UserStateData = [:]
    public var meta: UserStateData? = [:]
    public var state: UserStateVal = .enabled
    public var authLevel: UserAuthLevel = .unknown
}

extension UserState: Codable {
    public enum CodingKeys: String, CodingKey {
        case data, meta, state, isLoading
        case authLevel = "auth_level"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode([String: AnyCodable].self, forKey: .data)
        self.meta = try container.decodeIfPresent([String: AnyCodable].self, forKey: .meta) ?? [:]
        self.isLoading = try container.decodeIfPresent(Bool.self, forKey: .isLoading) ?? false
        self.state = try container.decodeIfPresent(UserStateVal.self, forKey: .state) ?? .enabled
        self.authLevel =
            try container.decodeIfPresent(UserAuthLevel.self, forKey: .authLevel) ?? .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(meta, forKey: .meta)
        try container.encode(isLoading, forKey: .isLoading)
        try container.encode(state, forKey: .state)
        try container.encode(authLevel, forKey: .authLevel)
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
        Task {
            await UserData.save(data)
        }
    }

    public func set(field: String, value: AnyCodable) {
        var userData = self.data
        userData[field] = value
        Task {
            await UserData.save(userData)
        }
    }

    internal func setMetaData(_ meta: [String: AnyCodable]) {
        Task {
            await UserData.saveMetaData(meta)
        }
    }

    internal func setMetaData(field: String, value: AnyCodable) {
        var meta = self.meta ?? [:]
        meta[field] = value
        Task {
            await UserData.saveMetaData(meta)
        }
    }
}

// MARK: - API / side-effect actions

// Easily unwrap the main payload from the `app` key
struct UserDataPayload: Codable {
    var data: [String: AnyCodable]
}

struct UserMetaDataPayload: Codable {
    var meta: [String: AnyCodable]
}

public struct UserStateResponse: Hashable, Codable, Sendable {
    public var data: UserStateData = [:]
    public var meta: UserStateData? = [:]
    public var state: UserStateVal = .enabled
    public var authLevel: UserAuthLevel = .unknown

    public enum CodingKeys: String, CodingKey {
        case data, meta, state
        case authLevel = "auth_level"
    }
}

public struct UserMetaDataResponse: Hashable, Sendable {
    public var id: String = ""
    public var meta: [String: AnyCodable] = [:]
}

extension UserMetaDataResponse: Codable {
    public enum CodingKeys: String, CodingKey {
        case id, meta
    }
}

extension UserStateResponse {
    func toUserState() -> UserState {
        return UserState(
            data: data,
            meta: meta ?? [:],
            state: state,
            authLevel: authLevel
        )
    }
}

class UserData {
    private static var fetchTask: Task<UserStateResponse?, Error>?

    /// Handle receiving user data from external source.
    static func onReceiveUserData(data: [String: AnyCodable], meta: [String: AnyCodable]? = nil) async {
        await Context.currentContext.store.mutate { state in
            state.user.data = data
            state.user.meta = meta ?? state.user.meta
            state.user.isLoading = false
        }
    }

    internal static func fetchUserData() async throws -> UserStateResponse? {
        if let handle = fetchTask {
            log.debug("User data fetch is already in progress")
            return try await handle.value
        }

        let task = Task.retrying { () throws -> UserStateResponse? in
            let state = Context.currentContext.store.state

            guard state.auth.isAuthenticated else {
                throw RowndError("User must be authenticated before fetching profile")
            }

            defer {
                fetchTask = nil
            }

            do {
                let user = try await Rownd.apiClient.send(
                    Request<UserStateResponse?>(
                        path: "/me/applications/\(state.appConfig.id ?? "unknown")/data",
                        method: .get)
                ).value

                log.debug("Decoded user response: \(String(describing: user))")

                guard let user = user else {
                    throw RowndError("Failed to load or decode user")
                }

                return user
            } catch {
                log.error("Failed to retrieve user: \(String(describing: error))")

                // If the user doesn't exist, sign out (user may have been deleted)
                if case .unacceptableStatusCode(let statusCode) = error as? APIError,
                    statusCode == 404
                {
                    log.warning(
                        "This user was not found (likely deleted), so they will be signed out.")
                    Rownd.signOut()
                    return nil
                }

                throw RowndError(
                    "Failed to retrieve user: \(error.localizedDescription)"
                )
            }
        }

        self.fetchTask = task

        return try await task.value
    }

    static func fetch() async {
        let state = Context.currentContext.store.state

        guard state.auth.isAuthenticated else {
            return
        }

        await Context.currentContext.store.setUserLoading(true)

        defer {
            Task {
                await Context.currentContext.store.setUserLoading(false)
            }
        }

        do {
            let userResponse = try await fetchUserData()

            guard let userResponse = userResponse else {
                return
            }

            await Context.currentContext.store.setUser(userResponse.toUserState())
        } catch {
            log.error(
                "Something went wrong while fetching the user's profile \(String(describing: error))"
            )
        }
    }

    static func save() async {
        await save(Context.currentContext.store.state.user.data)
    }

    static func save(_ data: [String: AnyCodable]) async {
        let state = Context.currentContext.store.state
        guard !state.user.isLoading else { return }

        // Update local state immediately
        await Context.currentContext.store.mutate { state in
            state.user.data = data
        }

        guard state.auth.isAuthenticated else {
            return
        }

        await Context.currentContext.store.setUserLoading(true)

        defer {
            Task {
                await Context.currentContext.store.setUserLoading(false)
            }
        }

        let userDataPayload = UserDataPayload(data: data)

        do {
            let user = try await Rownd.apiClient.send(
                Request<UserStateResponse?>(
                    path: "/me/applications/\(state.appConfig.id ?? "unknown")/data",
                    method: .put,
                    body: userDataPayload
                )
            ).value

            logger.debug("Decoded user response: \(String(describing: user))")

            await Context.currentContext.store.mutate { state in
                state.user.data = user?.data ?? [:]
                state.user.isLoading = false
            }
        } catch {
            logger.error("Failed to save user profile: \(String(describing: error))")
            await Context.currentContext.store.mutate { state in
                state.user.isErrored = true
                state.user.errorMessage = "The user profile could not be saved: \(String(describing: error))"
            }
        }
    }

    static func saveMetaData(_ meta: [String: AnyCodable]) async {
        let state = Context.currentContext.store.state
        guard !state.user.isLoading else { return }

        // Update local state immediately
        await Context.currentContext.store.mutate { state in
            state.user.meta = meta
        }

        guard state.auth.isAuthenticated else {
            return
        }

        do {
            let response = try await Rownd.apiClient.send(
                Request<UserMetaDataResponse?>(
                    path: "/me/meta",
                    method: .put,
                    body: UserMetaDataPayload(meta: meta)
                )
            ).value

            logger.debug("Saved Rownd meta data: \(String(describing: response))")
        } catch {
            logger.error("Failed to save meta data: \(String(describing: error))")
        }
    }
}
