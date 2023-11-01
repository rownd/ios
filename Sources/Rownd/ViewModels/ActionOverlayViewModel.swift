//
//  File.swift
//  
//
//  Created by Bobby Radford on 11/1/23.
//

import Foundation
import SwiftUI

protocol ActionOverlayViewModelProto {
    var state: ActionOverlayState { get }
    var fabImage: UIImage? { get }
    var fabTarget: Any { get }
    var fabAction: Selector { get }
    var fabTargetControlEvents: UIControl.Event { get }
}

enum ActionOverlayState {
    case initializing, ready, capturePage, capturingPage, success, failure
}

class ActionOverlayViewModel: NSObject, ActionOverlayViewModelProto {
    var state: ActionOverlayState
    var fabImage: UIImage? {
        get { return self.determineFabImage() }
    }
    lazy var fabTarget: Any = { return self }()
    lazy var fabAction: Selector = { return #selector(self.handleClick) }()
    var fabTargetControlEvents: UIControl.Event
    
    override init() {
        self.state = .capturePage
        self.fabTargetControlEvents = .touchUpInside
    }
    
    fileprivate func determineFabImage() -> UIImage? {
        switch self.state {
        case .capturePage:
            return UIImage(named: "RowndCamera", in: Bundle(for: Rownd.self), compatibleWith: nil)
        default:
            return UIImage(systemName: "trashcan")
        }
    }
    
    @objc func handleClick(_ sender: UIButton) {
        Rownd.capturePage()
    }
}
