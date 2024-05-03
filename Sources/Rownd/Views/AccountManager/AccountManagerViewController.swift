//
//  AccountManagerViewController.swift
//  RowndSDK
//
//  Created by Matt Hamann on 7/13/22.
//

import Foundation
import SwiftUI
import UIKit

public class AccountManagerViewController: UIViewController {

    let accountView = UIHostingController(rootView: AccountManager())

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

//        if let presentation = sheetPresentationController {
//            presentation.detents = [.large()]
//            presentation.prefersGrabberVisible = true
//        }
    }

    public override func loadView() {
        view = UIView()
        addChild(accountView)
        view.addSubview(accountView.view)
        setupConstraints()

        if Rownd.config.forceDarkMode {
            self.overrideUserInterfaceStyle = .dark
        }
    }

    func hide() {
        self.dismiss(animated: true)
    }

    fileprivate func setupConstraints() {
        accountView.view.translatesAutoresizingMaskIntoConstraints = false
        accountView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        accountView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        accountView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        accountView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }

}
