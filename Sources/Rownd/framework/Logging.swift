//
//  Logging.swift
//  Rownd
//
//  Created by Matt Hamann on 12/13/22.
//

import Foundation
import OSLog

class RowndLogger {
    static let shared = RowndLogger()
    private var listeners: [(String) -> Void] = []
    
    internal let logger = Logger(subsystem: "io.rownd.sdk", category: "Rownd")
    
    private init() {}
    
    func log(_ message: String) {
        let message = "LOG: \(message)"
        logger.log("\(message)")
        notifyListeners(message)
    }
    func error(_ message: String) {
        let message = "ERROR: \(message)"
        logger.error("\(message)")
        notifyListeners(message)
    }
    func debug(_ message: String) {
        let message = "DEBUG: \(message)"
        logger.debug("\(message)")
        notifyListeners(message)
    }
    func info(_ message: String) {
        let message = "INFO: \(message)"
        logger.info("\(message)")
        notifyListeners(message)
    }
    func warning(_ message: String) {
        let message = "WARNING: \(message)"
        logger.warning("\(message)")
        notifyListeners(message)
    }
    func trace(_ message: String) {
        let message = "TRACE: \(message)"
        logger.trace("\(message)")
        notifyListeners(message)
    }
    
    func addListener(_ listener: @escaping (String) -> Void) {
        listeners.append(listener)
    }
    
    private func notifyListeners(_ message: String) {
        for listener in listeners {
            listener(message)
        }
    }
}

internal let logger = RowndLogger.shared
