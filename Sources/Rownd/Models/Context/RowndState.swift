//
//  RowndState.swift
//
//
//  Created by Matt Hamann on 4/3/24.
//

import Foundation
import OSLog

private let log = Logger(subsystem: "io.rownd.sdk", category: "state")

private let STORAGE_STATE_KEY = "RowndState"

public struct RowndState: Codable, Hashable, Sendable {
    public var isStateLoaded = false
    internal var clockSyncState: ClockSyncState = NetworkTimeManager.shared.currentTime != nil ? .synced : .waiting
    public var appConfig = AppConfigState()
    public var auth = AuthState()
    public var user = UserState()
    public var passkeys = PasskeyState()
    public var signIn = SignInState()
    public var lastUpdateTs = Date()

    /// Creates a new RowndState with default values.
    public init() {
        self.isStateLoaded = false
        self.clockSyncState = NetworkTimeManager.shared.currentTime != nil ? .synced : .waiting
        self.appConfig = AppConfigState()
        self.auth = AuthState()
        self.user = UserState()
        self.passkeys = PasskeyState()
        self.signIn = SignInState()
        self.lastUpdateTs = Date()
    }
}

extension RowndState {
    enum CodingKeys: String, CodingKey {
        case appConfig, auth, user, signIn, passkeys, lastUpdateTs
    }

    public var isInitialized: Bool {
        return isStateLoaded && clockSyncState != .waiting
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appConfig = try container.decode(AppConfigState.self, forKey: .appConfig)
        auth = try container.decode(AuthState.self, forKey: .auth)
        user = try container.decode(UserState.self, forKey: .user)
        passkeys = try container.decodeIfPresent(PasskeyState.self, forKey: .passkeys) ?? PasskeyState()
        signIn = try container.decodeIfPresent(SignInState.self, forKey: .signIn) ?? SignInState()
        lastUpdateTs = try container.decodeIfPresent(Date.self, forKey: .lastUpdateTs) ?? Date()
    }

    public func toJson() throws -> String? {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            return String(data: encoded, encoding: .utf8)
        }

        throw StateError("Failed to encode state")
    }

    public func toDictionary() throws -> [String: Any?] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
    }
}

// MARK: - State Errors

struct StateError: Error, CustomStringConvertible {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}
