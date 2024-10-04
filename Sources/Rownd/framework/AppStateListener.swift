//
//  File.swift
//
//
//  Created by Matt Hamann on 4/26/24.
//

import Foundation
import UIKit

class AppStateListener {

    private let nc = NotificationCenter.default

    init() {
        nc.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc func appMovedToBackground() {
        // Future use
    }

    @objc func appMovedToForeground() {
        // Future use
    }
}
