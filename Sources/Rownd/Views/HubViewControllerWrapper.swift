//
//  HubWebViewControllerWrapper.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/17/22.
//

import Foundation
import UIKit
import SwiftUI

struct HubViewControllerWrapper: UIViewControllerRepresentable {

    var targetPage: HubPageSelector = .unknown
    var data: String = ""

    func makeUIViewController(context: Self.Context) -> HubViewController {
        let hubView = HubViewController()
        hubView.targetPage = targetPage
        hubView.hubWebController.jsFunctionArgsAsJson = data
        return hubView
    }

    func updateUIViewController(_ uiViewController: HubViewController, context: Self.Context) {

    }
}
