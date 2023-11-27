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
    var fabImage: UIImage? { get }
    var fabTarget: Any { get }
    var fabAction: Selector { get }
    var fabTargetControlEvents: UIControl.Event { get }
    var fabPosition: CGPoint { get set }
    var fabBackgroundColor: UIColor { get }
    var fabAlpha: CGFloat { get }
}

enum ActionOverlayState: String {
    case initializing, ready, success, failure
    case capturePage = "capture_page"
    case capturingPage = "capturing_page"
}

class ActionOverlayViewModel: NSObject, ActionOverlayViewModelProto {
    var state: ActionOverlayState
    var fabImage: UIImage? {
        get { return self.determineFabImage() }
    }
    lazy var fabTarget: Any = { return self }()
    lazy var fabAction: Selector = { return #selector(self.handleClick) }()
    var fabTargetControlEvents: UIControl.Event
    var fabPosition: CGPoint = CGPoint(x: -16, y: -16)
    var fabBackgroundColor: UIColor {
        get { return self.determineFabBackgroundColor() }
    }
    var fabAlpha: CGFloat {
        get { return self.state == .capturingPage ? 0.0 : 1.0 }
    }
    
    override init() {
        self.state = .initializing
        self.fabTargetControlEvents = .touchUpInside
    }
    
    fileprivate func determineFabBackgroundColor() -> UIColor {
        switch self.state {
        case .ready:
            return .yellow
        case .capturePage:
            return .purple
        case .success:
            return .green
        case .failure:
            return .red
        default:
            return .white
        }
    }
    
    fileprivate func determineFabImage() -> UIImage? {
        switch self.state {
        case .capturePage:
//            return UIImage(named: "camera", in: Bundle(for: Rownd.self), compatibleWith: nil)
            return UIImage(named: "camera", in: Bundle(for: Rownd.self), compatibleWith: nil)
        case .success:
//            return UIImage(named: "success", in: Bundle(for: Rownd.self), compatibleWith: nil)
            return UIImage(named: "camera", in: Bundle(for: Rownd.self), compatibleWith: nil)
        case .failure:
//            return UIImage(named: "failure", in: Bundle(for: Rownd.self), compatibleWith: nil)
            return UIImage(named: "camera", in: Bundle(for: Rownd.self), compatibleWith: nil)
        default:
//            return UIImage(named: "rownd", in: Bundle(for: Rownd.self), compatibleWith: nil)
            return UIImage(named: "camera", in: Bundle(for: Rownd.self), compatibleWith: nil)

        }
    }
    
    @objc func handleClick(_ sender: UIButton) {
        Rownd.capturePage()
    }
}
