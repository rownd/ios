//
//  Constants.swift
//  RowndSDK
//
//  Created by Matt Hamann on 7/12/22.
//

import Foundation
import UIKit

func getFrameworkBundle() -> Bundle {
    return Bundle(for: Rownd.self)
}

func getFrameworkVersion() -> String {
    return SDK_VERSION
}

struct FrameworkFeature: Codable {
    var name: String
    var enabled: String
}

func getFrameworkFeatures() -> String {
    let frameworkFeatures: [FrameworkFeature] = [
        FrameworkFeature(name: "openEmailInbox", enabled: "true"),
        FrameworkFeature(name: "can_receive_event_messages", enabled: "true")
    ]

    let encoder = JSONEncoder()
    encoder.dataEncodingStrategy = .base64

    do {
        let encodedData = try encoder.encode(frameworkFeatures)
        return String(data: encodedData, encoding: .utf8) ?? "{}"
    } catch {
        logger.warning("Failed to encode framework features: \(String(describing: error)))")
        return "[]"
    }
}

struct Constants {
    static private let formatter = ISO8601DateFormatter()

    static let BACKGROUND_LIGHT = UIColor.white
    static let BACKGROUND_DARK = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)

    static var DEFAULT_API_USER_AGENT: String {
        get {
            return "Rownd SDK for iOS/\(getFrameworkVersion()) (Language: Swift; Platform: \(UIDevice.current.systemName) \(ProcessInfo.processInfo.operatingSystemVersionString))"
        }
    }

    static var DEFAULT_WEB_USER_AGENT: String {
        get {
            return "Rownd SDK for iOS/\(getFrameworkVersion()) (Language=Swift; Platform: \(UIDevice.current.systemName) \(ProcessInfo.processInfo.operatingSystemVersionString))"
        }
    }

    static var TIME_META_HEADER_NAME = "X-Rownd-Time-Meta"
    static var TIME_META_HEADER: String {
        get {
            let currentTime = NetworkTimeManager.shared.currentTime ?? Date()
            let timeSource = NetworkTimeManager.shared.currentTime != nil ? "ntp" : "local"
            return "timestamp=\(formatter.string(from: currentTime))&timesource=\(timeSource)"
        }
    }
}
