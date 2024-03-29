//
//  File.swift
//  
//
//  Created by Matt Hamann on 3/28/24.
//

import Foundation

internal enum ClockSyncState: String, Codable {
    case waiting = "waiting"
    case synced = "synced"
    case failed = "failed"
    case unknown = "unknown"
}
