//
//  KeyTransferViewController.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/13/22.
//

import Foundation
import SwiftUI
import Get

class KeyTransferViewState : ObservableObject {
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

class KeyTransferViewController : UIViewController {

    lazy var contentView: UIHostingController<KeyTransferView> = UIHostingController(rootView: KeyTransferView(
        parentViewController: self,
        setupKeyTransfer: self.setupKeyTransfer,
        receiveKeyTransfer: self.receiveKeyTransfer,
        keyState: self.keyState
    ))
    var keyState = KeyTransferViewState()

    private func uiColorAs1ptImage(_ color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContext(CGSizeMake(1, 1))
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        color.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    override func loadView() {
        super.loadView()

        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithOpaqueBackground()
        coloredAppearance.backgroundColor = Rownd.config.customizations.sheetBackgroundColor
        coloredAppearance.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance

//        UIToolbar.appearance().barTintColor = Rownd.config.customizations.sheetBackgroundColor
        
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

    private func setupKeyTransfer() {
        do {
            let keyId = try Rownd.user.getKeyId()
            let key = RowndEncryption.loadKey(keyId: keyId)
            keyState.key = key?.asData().base64EncodedString() ?? "Error"
        } catch {
            logger.error("Failed to load key for transfer: \(String(describing: error))")
            keyState.key = "Error"
        }

        Task {
            do {
                let magicLink: MagicLink = try await Rownd.apiClient.send(Get.Request(method: "post", url: "/me/auth/magic")).value
                keyState.signInLink = magicLink.link
            } catch {
                logger.error("Failed to fetch magic link: \(String(describing: error))")
            }
        }
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
