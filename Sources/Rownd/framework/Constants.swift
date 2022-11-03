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
    var bundleVersion = "unknown"
    if let _bundleVersion = getFrameworkBundle().infoDictionary?["CFBundleShortVersionString"] as? String {
        bundleVersion = _bundleVersion
    }
    
    return bundleVersion
}

struct FrameworkFeature: Codable {
    var name: String
    var enabled: String
}

func getFrameowrkFeatures() -> String {
    let frameworkFeatures: [FrameworkFeature] = [FrameworkFeature(name: "openEmailInbox", enabled: "true")]
    
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



let DEFAULT_API_USER_AGENT = "Rownd SDK for iOS/\(getFrameworkVersion()) (Language: Swift; Platform=\(UIDevice.current.systemName) \(ProcessInfo.processInfo.operatingSystemVersionString);)"

let DEFAULT_WEB_USER_AGENT = "Rownd SDK for iOS/\(getFrameworkVersion()) (Language: Swift; Platform=\(UIDevice.current.systemName) \(ProcessInfo.processInfo.operatingSystemVersionString);)"
