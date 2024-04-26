//
//  RowndStorage.swift
//  ios native
//
//  Created by Matt Hamann on 6/15/22.
//

import Foundation

struct Storage {
    private init() {}

    private static var defaultStore = UserDefaults(suiteName: "io.rownd.sdk")

    private static func computeSharedStorageKey() -> String? {
        guard let storagePrefix = Rownd.config.sharedStoragePrefix else {
            return nil
        }

        return storagePrefix + ".io.rownd.sdk"
    }

    static func get(forKey key: String) -> String? {
        guard let storageKey = computeSharedStorageKey() else {
            return defaultStore?.object(forKey: key) as? String
        }

        let store = UserDefaults(suiteName: storageKey)

        // This helps us fall back to default store in the event that an app is
        // migrating from default store to a group container
        guard let value = store?.object(forKey: key) as? String else {
            return defaultStore?.object(forKey: key) as? String
        }

        return value
    }

    static func set(_ value: String, forKey key: String) {
        guard let storageKey = computeSharedStorageKey() else {
            defaultStore?.set(value, forKey: key)
            return
        }

        let store = UserDefaults(suiteName: storageKey)
        store?.set(value, forKey: key)

        // We always store in the default store just in case a group
        // container setup is removed
        defaultStore?.set(value, forKey: key)
    }
}
