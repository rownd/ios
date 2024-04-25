//
//  File.swift
//  
//
//  Created by Bobby Radford on 11/1/23.
//

import Foundation
import SwiftUI

protocol ActionOverlayViewModelProto {
    var state: ActionOverlayState { get set }
    // TODO: get rid of all the fabXXX props and use this nested view model
//    var fab: FloatingActionButtonViewModel { get }
    var fabImage: UIImage? { get }
    var fabImageInsets: UIEdgeInsets { get }
    var fabTarget: Any { get }
    var fabAction: Selector { get }
    var fabTargetControlEvents: UIControl.Event { get }
    var fabPosition: CGPoint { get set }
    var fabBackgroundColor: UIColor { get }
    var fabAlpha: CGFloat { get }
    var pageId: String? { get set }
}

enum ActionOverlayState: String, Codable {
    case initializing, ready, success, failure
    case captureScreen = "capture_screen"
    case capturingScreen = "capturing_screen"
}

class ActionOverlayViewModel: NSObject, ActionOverlayViewModelProto {
    var state: ActionOverlayState
//    lazy var fab: FloatingActionButtonViewModel = {
//        return FloatingActionButtonViewModel(parent: self)
//    }()
    var fabImage: UIImage? {
        get { return self.determineFabImage() }
    }
    var fabImageInsets: UIEdgeInsets {
        get { return self.determineFabImageInsets() }
    }
    lazy var fabTarget: Any = { return self }()
    lazy var fabAction: Selector = { return #selector(self.handleClick) }()
    var fabTargetControlEvents: UIControl.Event
    var fabPosition: CGPoint = CGPoint(x: -16, y: -16)
    var fabBackgroundColor: UIColor = .white
    var fabAlpha: CGFloat {
        get { return self.state == .capturingScreen ? 0.0 : 1.0 }
    }
    var pageId: String?
    
    override init() {
        self.state = .ready
        self.fabTargetControlEvents = .touchUpInside
    }
    
    fileprivate func determineFabImage() -> UIImage? {
        switch self.state {
        case .captureScreen:
            let image = UIImage(named: "camera", in: Bundle.module, compatibleWith: nil)
            return image?.withTintColor(UIColor.rowndPurple)
        case .success:
            let image = UIImage(named: "checkmark", in: Bundle.module, compatibleWith: nil)
            return image?.withTintColor(UIColor.systemGreen)
        case .failure:
            let image = UIImage(named: "close--filled", in: Bundle.module, compatibleWith: nil)
            return image?.withTintColor(UIColor.systemRed)
        default:
            let image = UIImage(named: "rownd", in: Bundle.module, compatibleWith: nil)
            return image?.withTintColor(UIColor.rowndPurple)
        }
    }
    
    fileprivate func determineFabImageInsets() -> UIEdgeInsets {
        switch self.state {
        case .captureScreen:
            return UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        default:
            return UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        }
    }
    
    @objc func handleClick(_ sender: UIButton) {
        switch self.state {
        case .captureScreen:
            Rownd.actionOverlay.actions.captureScreen(forPageId: self.pageId)
        default:
            return
        }
    }
}
