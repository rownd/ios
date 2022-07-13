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


let DEFAULT_API_USER_AGENT = "Rownd SDK for iOS/\(getFrameworkVersion()) (Language: Swift; Platform=\(UIDevice.current.systemName) \(ProcessInfo.processInfo.operatingSystemVersionString);)"

let DEFAULT_WEB_USER_AGENT = "Rownd SDK for iOS/\(getFrameworkVersion()) (Language: Swift; Platform=\(UIDevice.current.systemName) \(ProcessInfo.processInfo.operatingSystemVersionString);)"
