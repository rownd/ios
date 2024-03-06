//
//  Logging.swift
//  Rownd
//
//  Created by Matt Hamann on 12/13/22.
//

import Foundation
import OSLog

internal let logger = Logger(subsystem: "io.rownd.sdk", category: "Rownd")
internal let autoLogger = AutomationLogger()

internal struct AutomationLogger {
    var _logger = Logger(subsystem: "io.rownd.sdk", category: "Rownd Automations")

    func log(_ message: String) -> Void {
        if Rownd.config.debugAutomations {
            _logger.log("\(message)")
        }
    }

    func warning(_ message: String) -> Void {
        if Rownd.config.debugAutomations {
            _logger.warning("\(message)")
        }
    }
}
