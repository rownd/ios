//
//  KeyTransferViewController.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/13/22.
//

import Foundation
import SwiftUI

class KeyTransferViewState : ObservableObject {
    @Published var key = "Loading..."
    var qrCodeData: String {
        get {
            do {
                return try ["data": "https://rownd.io/#\(self.key)"].asJsonString()
            } catch {
                return "Error fetching QR Code data: \(String(describing: error))"
            }
        }
    }

}

class KeyTransferViewController : UIViewController {

    lazy var contentView: UIHostingController<KeyTransferView> = UIHostingController(rootView: KeyTransferView(
        parentViewController: self,
        keyState: keyState
    ))
    var keyState = KeyTransferViewState()

    override func loadView() {
        super.loadView()

        do {
            let keyId = try Rownd.user.getKeyId()
            let key = RowndEncryption.loadKey(keyId: keyId)
            keyState.key = key?.asData().base64EncodedString() ?? "Error"
        } catch {
            logger.error("Failed to load key for transfer: \(String(describing: error))")
            keyState.key = "Error"
            keyState
        }
        
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

}
