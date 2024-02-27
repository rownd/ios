//
//  RowndDeviceUtils.swift
//
//
//  Created by Bobby Radford on 1/26/24.
//

import Foundation
import UIKit

internal class RowndDeviceUtils {
    static func mainWindow() async throws -> UIWindow? {
        let task = Task { @MainActor () -> UIWindow? in
            let allScenes = UIApplication.shared.connectedScenes
            for scene in allScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows where window.isKeyWindow {
                   return window
                }
            }
            return nil
        }
        return try await task.result.get()
    }
}
