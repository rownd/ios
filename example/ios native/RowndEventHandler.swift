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
        print(String(describing: event))
    }
}
