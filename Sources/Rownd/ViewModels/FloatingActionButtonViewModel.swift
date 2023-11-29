//
//  File.swift
//  
//
//  Created by Bobby Radford on 11/1/23.
//

// This view model is not presently used, but could be nice to isolate FAB logic to its
// own view model. I wanted to put this as a property in the ActionOverlayViewModel, however,
// I could not figure out a good way to get notified of updates to nested property changes
// within the controller.

import Foundation
import SwiftUI

protocol FloatingActionButtonViewModelProto {
    var image: UIImage? { get }
    var imageInsets: UIEdgeInsets { get }
    var target: Any { get }
    var action: Selector { get }
    var targetControlEvents: UIControl.Event { get }
    var position: CGPoint { get set }
    var backgroundColor: UIColor { get }
    var alpha: CGFloat { get }
}

class FloatingActionButtonViewModel: NSObject, FloatingActionButtonViewModelProto {
    private var parent: ActionOverlayViewModel
    var image: UIImage? {
        get { return self.determineFabImage() }
    }
    var imageInsets: UIEdgeInsets {
        get { return self.determineFabImageInsets() }
    }
    lazy var target: Any = { return self }()
    lazy var action: Selector = { return #selector(self.handleClick) }()
    var targetControlEvents: UIControl.Event = .touchUpInside
    var position: CGPoint = CGPoint(x: -16, y: -16)
    var backgroundColor: UIColor = .white
    var alpha: CGFloat {
        get { return self.parent.state == .capturingPage ? 0.0 : 1.0 }
    }
    
    init(parent: ActionOverlayViewModel) {
        self.parent = parent
    }
    
    fileprivate func determineFabImage() -> UIImage? {
        switch self.parent.state {
        case .capturePage:
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
        switch self.parent.state {
        case .capturePage:
            return UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        default:
            return UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        }
    }
    
    @objc func handleClick(_ sender: UIButton) {
        switch self.parent.state {
        case .capturePage:
            Rownd.capturePage()
        default:
            return
        }
    }
}
