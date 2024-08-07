//
//  KeyTransferViewController.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/13/22.
//

import Foundation
import SwiftUI
import Get
import LBBottomSheet

class KeyTransferViewState: ObservableObject {
    @Published var key = "Loading..."
    @Published var signInLink: String = ""
    @Published var isReceivingKey = false
    @Published var operationError: String?

    var qrCodeData: String {
        do {
            return try ["data": "\(self.signInLink)#\(self.key)"].asJsonString()
        } catch {
            return "Error fetching QR Code data: \(String(describing: error))"
        }
    }

}

class KeyTransferViewController: UIViewController, BottomSheetControllerProtocol, BottomSheetHostProtocol {

    var hostController: BottomSheetController?

    lazy var contentView: UIHostingController<KeyTransferView> = UIHostingController(rootView: KeyTransferView(
        parentViewController: self,
        receiveKeyTransfer: self.receiveKeyTransfer,
        keyState: self.keyState
    ))
    var keyState = KeyTransferViewState()

    var detents: [LBBottomSheet.BottomSheetController.Behavior.HeightValue] = [.screenRatio(value: 0.7), .screenRatio(value: 0.9)]

    override func loadView() {
        super.loadView()

        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithOpaqueBackground()
        coloredAppearance.backgroundColor = Rownd.config.customizations.sheetBackgroundColor
        coloredAppearance.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance

        addChild(contentView)
        view.addSubview(contentView.view)

        setupConstraints()
    }

    fileprivate func setupConstraints() {
        contentView.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contentView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }

    public override func viewWillDisappear(_ animated: Bool) {
        guard let hostController = hostController else {
            return
        }

        hostController.dismiss(animated: true)
    }

    private func receiveKeyTransfer(_ url: String) {
        keyState.isReceivingKey = true
        keyState.operationError = nil

        Task {
            let url = URL(string: url)

            guard let url = url else {
                keyState.operationError = "The key received was not valid."
                keyState.isReceivingKey = false
                return
            }

            do {
                try await SignInLinks.signInWithLink(url)
                keyState.isReceivingKey = false
            } catch {
                keyState.operationError = "Key transfer failed. Please try again."
                keyState.isReceivingKey = false
            }
        }
    }

}
