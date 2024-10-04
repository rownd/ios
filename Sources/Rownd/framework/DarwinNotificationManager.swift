//
//  DarinNotificationManager.swift
//  Rownd
//
//  Created by Matt Hamann on 10/3/24.
//

import Foundation
import OSLog

class DarwinNotificationManager {
    static let shared = DarwinNotificationManager()
    private static let log = Logger(subsystem: "io.rownd.sdk", category: "ips")
    
    private init() {}
    
    private var callbacks: [String: () -> Void] = [:]
    
    // Post a Darwin notification
    func postNotification(name: String) {
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(notificationCenter, CFNotificationName(name as CFString), nil, nil, true)
        DarwinNotificationManager.log.debug("Sent signal: \(name)")
    }
    
    func startObserving(name: String, callback: @escaping () -> Void) {
        callbacks[name] = callback
        
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        
        CFNotificationCenterAddObserver(notificationCenter,
                                        Unmanaged.passUnretained(self).toOpaque(),
                                        DarwinNotificationManager.notificationCallback,
                                        name as CFString,
                                        nil,
                                        .deliverImmediately)
    }
    
    func stopObserving(name: String) {
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveObserver(notificationCenter, Unmanaged.passUnretained(self).toOpaque(), CFNotificationName(name as CFString), nil)
        callbacks.removeValue(forKey: name)
    }
    
    // 4
    private static let notificationCallback: CFNotificationCallback = { center, observer, name, _, _ in
        guard let observer = observer else { return }
        let manager = Unmanaged<DarwinNotificationManager>.fromOpaque(observer).takeUnretainedValue()
        
        log.debug("Received signal: \(name?.rawValue)")
        
        if let name = name?.rawValue as String?, let callback = manager.callbacks[name] {
            callback()
        }
    }
}
