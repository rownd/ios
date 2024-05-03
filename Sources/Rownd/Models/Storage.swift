//
//  RowndStorage.swift
//  ios native
//
//  Created by Matt Hamann on 6/15/22.
//

import Foundation
import OSLog

class Storage: NSObject, NSFilePresenter {
    private static let log = Logger(subsystem: "io.rownd.sdk", category: "storage")

    private let defaultContainerName = "io.rownd.sdk"
    @available(*, deprecated, message: "Use NSFileCoordinator instead")
    private lazy var userDefaultsStore = UserDefaults(suiteName: defaultContainerName)

    private let debouncer = Debouncer(delay: 0.1) // 100ms
    static var shared = Storage()
    private let operationQueue: OperationQueue

    var presentedItemURL: URL? {
        guard let sharedPrefix = Rownd.config.appGroupPrefix else {
            return computeAppStoragePath()
        }
        return computeSharedStoragePath(sharedPrefix)
    }

    var presentedItemOperationQueue: OperationQueue {
        return operationQueue
    }

    override init() {
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        super.init()

        NSFileCoordinator.addFilePresenter(self)
    }

    func presentedItemDidChange() {
        debouncer.debounce(action: {
            Self.log.debug("Change detected!")
            Task {
                await Context.currentContext.store.state.reload()
            }
        })
    }

    private func computeSharedStoragePath(_ prefix: String? = nil) -> URL? {
        guard let storagePrefix = prefix else {
            return nil
        }

        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "\(storagePrefix).\(defaultContainerName)")
    }

    private func computeAppStoragePath() -> URL? {
        return try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(defaultContainerName)
    }

    private func writeToStorage(_ value: String, fileUrl: URL) {

        let fileCoordinator: NSFileCoordinator = NSFileCoordinator(filePresenter: self)
        let errorPointer: NSErrorPointer = nil
        fileCoordinator.coordinate(writingItemAt: fileUrl, options: .forReplacing, error: errorPointer) { url in
            do {
                try value.write(to: url, atomically: false, encoding: .utf8)
            } catch {
                Self.log.error("Writing state failed \(String(describing: error))")
            }
        }

        if let error = errorPointer?.pointee {
            Self.log.error("Storage write coordination failed: \(error.localizedDescription).")
        }
    }

    private func readFromStorage(_ fileUrl: URL) -> String? {
        var data: String?
        let fileCoordinator: NSFileCoordinator = NSFileCoordinator(filePresenter: self)
        fileCoordinator.coordinate(readingItemAt: fileUrl, options: [], error: nil) { url in
            if let contents = try? String(contentsOf: url, encoding: .utf8) {
                data = contents
            }
        }

        return data
    }

    func get(forKey key: String) -> String? {
        //        guard let fileUrl = computeStoragePath(key) else {
        //            return defaultStore?.object(forKey: key) as? String
        //        }

        // Try to read from shared container (app group)
        var value: String?
        if let sharedFileUrl = computeSharedStoragePath(Rownd.config.appGroupPrefix) {
            value = readFromStorage(sharedFileUrl.appendingPathComponent(key))
            Self.log.debug("Read from shared container: \(String(describing: value))")
        }

        // If that fails, read from primary app container
        guard value == nil else {
            Self.log.debug("Returning data from shared container")
            return value
        }

        if let appFileUrl = computeAppStoragePath() {
            value = readFromStorage(appFileUrl.appendingPathComponent(key))
            Self.log.debug("Read from app container: \(String(describing: value))")
        }

        guard value == nil else {
            Self.log.debug("Returning data from app container")
            return value
        }

        // If we don't get anything, try the legacy UserDefaults store
        value = userDefaultsStore?.object(forKey: key) as? String
        Self.log.debug("Read from UserDefaults: \(String(describing: value))")
        return value
    }

    func set(_ value: String, forKey key: String) {

        // If shared folder enabled, write to that
        if let sharedFileUrl = computeSharedStoragePath(Rownd.config.appGroupPrefix) {
            writeToStorage(value, fileUrl: sharedFileUrl.appendingPathComponent(key))
            Self.log.debug("Successfully wrote to \(String(describing: sharedFileUrl.appendingPathComponent(key)))")
        }

        // Always write to default
        appFileIf: if let appFileUrl = computeAppStoragePath() {
            if !FileManager.default.fileExists(atPath: appFileUrl.absoluteString) {
                do {
                    try FileManager.default.createDirectory(at: appFileUrl, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    Self.log.error("Failed to create storage directory: \(String(describing: error))")
                    break appFileIf
                }
            }

            writeToStorage(value, fileUrl: appFileUrl.appendingPathComponent(key))
            Self.log.debug("Successfully wrote to \(String(describing: appFileUrl.appendingPathComponent(key)))")
        }
    }
}
