//
//  CustomActivityViewController.swift
//  RowndSDK
//
//  Created by Matt Hamann on 7/14/22.
//

import UIKit
import LBBottomSheet

protocol BottomSheetControllerProtocol {
    var detents: [LBBottomSheet.BottomSheetController.Behavior.HeightValue] { get set }
}

protocol BottomSheetHostProtocol {
    var hostController: BottomSheetController? { get set }
}

class BottomSheetController: UIViewController {
    
    var controller: UIViewController?
    var sheetController: LBBottomSheet.BottomSheetController?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let controller = controller else {
            return
        }

        if var hubViewController = controller as? BottomSheetHostProtocol {
            hubViewController.hostController = self
        }
        
        var behavior: LBBottomSheet.BottomSheetController.Behavior = .init(swipeMode: .full)
        if let controller = controller as? BottomSheetControllerProtocol {
            behavior.heightMode = .specific(values: controller.detents, heightLimit: .statusBar)
        } else {
            behavior.heightMode = .fitContent()
        }
        
        subscribeToNotification(UIResponder.keyboardWillShowNotification, selector: #selector(keyboardWillShow))
        
        var theme: LBBottomSheet.BottomSheetController.Theme = .init()
        theme.cornerRadius = Rownd.config.customizations.sheetCornerBorderRadius
        theme.shadow?.color = .systemGray6
        theme.dimmingBackgroundColor = UIColor.black.withAlphaComponent(CGFloat(0.25))

        theme.grabber?.topMargin = CGFloat(10.0)
        theme.grabber?.size = CGSize(width: 100.0, height: 5.0)
        
        sheetController = presentAsBottomSheet(controller, theme: theme, behavior: behavior)

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //Unsubscribe from all our notifications
        unsubscribeFromAllNotifications()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.controller = nil
    }
    
    func updateBottomSheetHeight(_ number: CGFloat) {
        if let sheetController = sheetController {
            guard let controller = self.controller else {
                return
            }
            DispatchQueue.main.async {
                guard let hubViewController = controller as? HubViewController else {
                    return
                }
                hubViewController.preferredHeightInBottomSheet = Double.minimum(number, UIScreen.main.bounds.height * 0.90)
                sheetController.preferredHeightInBottomSheetDidUpdate()
            }
        }
    }
    
    func canTouchDimmingBackgroundToDismiss(_ enable: Bool) {
        if let sheetController = sheetController {
            sheetController.setCanTouchDimmingBackgroundToDismiss(enable)
        }
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
            guard let controller = self.controller else {
                return
            }
            DispatchQueue.main.async {
                guard let hubViewController = controller as? HubViewController else {
                    return
                }
                hubViewController.preferredHeightInBottomSheet = UIScreen.main.bounds.height * 0.9
                sheetController.preferredHeightInBottomSheetDidUpdate()
            }
        }
    }
}
