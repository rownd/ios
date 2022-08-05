//
//  CustomActivityViewController.swift
//  RowndSDK
//
//  Created by Matt Hamann on 7/14/22.
//

import UIKit
import LBBottomSheet

class BottomSheetController: UIViewController {
    
    var controller: UIViewController?
    var sheetController: LBBottomSheet.BottomSheetController?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let controller = controller else {
            return
        }

        if var hubViewController = controller as? HubViewProtocol {
            hubViewController.hostController = self
        }
        
        var behavior: LBBottomSheet.BottomSheetController.Behavior = .init(swipeMode: .full)
        behavior.heightMode = .specific(values: [.screenRatio(value: 0.5), .screenRatio(value: 0.9)], heightLimit: .statusBar)
        
        var theme: LBBottomSheet.BottomSheetController.Theme = .init()
        theme.grabber?.topMargin = CGFloat(10.0)
        
        sheetController = presentAsBottomSheet(controller, theme: theme, behavior: behavior)

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        subscribeToNotification(UIResponder.keyboardWillShowNotification, selector: #selector(keyboardWillShow))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //Unsubscribe from all our notifications
        unsubscribeFromAllNotifications()
    }
}

extension BottomSheetController {
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        // Get required info out of the notification
        if let sheetController = sheetController {
            sheetController.grow(toMaximumHeight: true)
        }
    }
}
