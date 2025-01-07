//
//  RowndEventHandler.swift
//  rownd_ios_example
//
//  Created by Matt Hamann on 5/15/24.
//

import Foundation
import Rownd

class RowndEventHandler: RowndEventHandlerDelegate {
    func handleRowndEvent(_ event: RowndEvent) {
        switch event.event {
        case .signInCompleted:
            let userType = event.data?["user_type"]
            let appVariantUserType = event.data?["app_variant_user_type"]
            break

        default:
            break
        }
    }
}
