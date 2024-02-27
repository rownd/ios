//
//  UINavigationController+RowndInfo.swift
//
//
//  Created by Bobby Radford on 2/8/24.
//

import Foundation
import SwiftUI

internal extension UINavigationController {
    var rownd_info: UINavigationControllerInfo {
        return UINavigationControllerInfo(
            title: self.title
        )
    }
}

internal struct UINavigationControllerInfo {
    var title: String?
}

extension UIWindow {
    func getNavigationController() -> UINavigationController? {
        guard let rootViewController = self.rootViewController else {
            return nil
        }
        return getNavigationController(from: rootViewController)
    }
    
    private func getNavigationController(from viewController: UIViewController) -> UINavigationController? {
        if let navigationController = viewController as? UINavigationController {
            return navigationController
        }
        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return getNavigationController(from: selectedViewController)
        }
        if let presentedViewController = viewController.presentedViewController {
            return getNavigationController(from: presentedViewController)
        }
        return nil
    }
}
