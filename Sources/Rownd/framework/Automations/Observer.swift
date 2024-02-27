//
//  File.swift
//  
//
//  Created by Bobby Radford on 11/29/23.
//

import Foundation
import SwiftUI
import UIKit

private protocol AnyUIHostingViewController: AnyObject {}
extension UIHostingController: AnyUIHostingViewController {}

extension UIViewController {
   var isHostingController: Bool { self is AnyUIHostingViewController }
}

extension UIResponder {

    /// The responder chain from the target responder (self)
    ///     to the `UIApplication` and the app delegate
    var responderChain: [UIResponder] {
        var responderChain: [UIResponder] = []
        var currentResponder: UIResponder? = self

        while currentResponder != nil {
            if let controller = currentResponder as? UIViewController {
                responderChain.append(controller)
            } else if let view = currentResponder as? UIView {
                responderChain.append(view)
            }
            currentResponder = currentResponder?.next
        }

        return responderChain
    }
    
    var rowndSelector: String {
        let indexOfFirstVisibleView = responderChain.firstIndex(where: {
            if let view = $0 as? UIView {
                return view.alpha < 1.0
            }
            return false
        }) ?? responderChain.endIndex
        
        let subsequence = responderChain.prefix(upTo: indexOfFirstVisibleView)
        let chain = subsequence.reversed()

        let processed = chain.enumerated().map { (index, responder) in
            var siblings: [UIResponder] = []
            
            if let _ = responder as? UIWindow {
                siblings = UIApplication.shared.windows.filter {
                    // After the HubView loads once, an additional UITextEffectsWindow UIWindow is created
                    // whish was throwing off the matching of a view because the UIWindow:siblings(n) would
                    // increase. I don't know why this UITextEffectsWindow shows up, but perhaps we
                    // can ignore it?
                    return String(describing: type(of: $0)) != "UITextEffectsWindow"
                }
            }

            if index > 0 {
                let idx = chain.index(chain.startIndex, offsetBy: index - 1)
                let nextResponder = chain[idx]
                
                if let parentViewController = nextResponder as? UIViewController {
                    if let view = parentViewController.viewIfLoaded {
                        siblings = [view]
                    }
                    if !parentViewController.children.isEmpty {
                        siblings.append(contentsOf: parentViewController.children)
                    }
                } else if let parentView = nextResponder as? UIView {
                    siblings = parentView.subviews
                }
            }
            
            let currIndex = siblings.count == 1 ? 0 : siblings.firstIndex(where: {
                if let controller = responder as? UIViewController, let view = controller.viewIfLoaded {
                    if view == $0 { return true }
                }
                return $0 == responder
            }) ?? -1
            
//            let addr = Unmanaged.passUnretained(responder).toOpaque()
            
//            var alpha = "n/a"
//            if let view = responder as? UIView {
//                alpha = "\(view.alpha)"
//            }

            return "\(String(describing: type(of: responder))):nth-child(\(currIndex)):siblings(\(siblings.count - 1))"
        }
        
        
        return processed.joined(separator: "\n > ")
    }
}

class ViewHierarchyInfo: Codable {
    var type: String
    var parent: ViewHierarchyInfo?
    var siblings: [ViewHierarchyInfo]?

    init(type: String) {
        self.type = type
    }
}

extension UIApplication {
    @objc dynamic func _swizzled_sendEvent(_ event: UIEvent) {
        _swizzled_sendEvent(event)

        if event.allTouches != nil {
            let touches: Set<UITouch> = event.allTouches!
            let touch: UITouch = touches.first!

            // Try to determine the closest relevant view that was tapped.
            // TODO: This enire algorithm needs work. Perhaps we should search through
            // accessibilityElements instea.
            Task { @MainActor in
                if let tView = touch.view {
                    // If the tapped view is transparent, then the user probably intended to tap on a
                    // view beneath the current view. Try to find sibling a sibling view whose frame
                    // encompasses the
                    var approximatedTarget: UIView = tView
                    let bgColor = tView.backgroundColor ?? UIColor.clear
                    if tView.alpha == 0.0 || bgColor == UIColor.clear {
                        var siblings: [UIView] = []
                        if let siblingViews = tView.superview?.subviews, !siblingViews.isEmpty {
                            siblings.append(contentsOf: siblingViews)
                        }
                        
                        if let nextResponder = tView.next {
                            if let controller = nextResponder as? UIViewController {
                                if let view = controller.viewIfLoaded {
                                    siblings.append(view)
                                }
                                if !controller.children.isEmpty {
                                    let controllerChildrenViews = controller.children.map {
                                        $0.viewIfLoaded
                                    }
                                    controllerChildrenViews.forEach {
                                        if let view = $0 {
                                            siblings.append(view)
                                        }
                                    }
                                }
                            }
                        }
                        
                        
//                        var smallestFrameArea = CGFloat(Int.max)
//                        let smallestFramedSibling = siblings.filter {
//                            $0 != tView
//                        }.reduce(nil as UIView?) { (result, sibling) in
//                            let touchLocationInWindow = touch.location(in: nil)
//                            let touchWasInViewFrame = touchLocationInWindow.x >= sibling.frame.minX && touchLocationInWindow.x <= sibling.frame.maxX && touchLocationInWindow.y >= sibling.frame.minY && touchLocationInWindow.y <= sibling.frame.maxY
//                            let siblingFrameArea = sibling.frame.height * sibling.frame.width
//                            
//                            if touchWasInViewFrame && siblingFrameArea.isLess(than: smallestFrameArea) {
//                                smallestFrameArea = siblingFrameArea
//                                return sibling
//                            } else {
//                                return result
//                            }
//                        }
//                        
//                        if let _found = smallestFramedSibling {
//                            approximatedTarget = _found
//                        }
                    }
                    
                    // This can't be robust, but seems to work in some cases.
                    if String(describing: type(of: tView)) == "_UIShapeHitTestingView" {
                        if let nextView = tView.next as? UIView {
                            approximatedTarget = nextView
                        }
                    }
                    
                    // Visually indicate the approximated target for debugging
                    if Rownd.config.debugAutomations {
                        let prevAlpha = approximatedTarget.alpha
                        let prevBorderColor = approximatedTarget.layer.borderColor
                        let prevBorderWidth = approximatedTarget.layer.borderWidth

                        Task { @MainActor in
//                            approximatedTarget.backgroundColor = UIColor.black
                            approximatedTarget.layer.borderColor = CGColor.rowndPurple
                            approximatedTarget.layer.borderWidth = CGFloat(4.0)
                            
                            try! await Task.sleep(nanoseconds: 200_000_000)
                            
                            approximatedTarget.alpha = prevAlpha
                            approximatedTarget.layer.borderColor = prevBorderColor
                            approximatedTarget.layer.borderWidth = prevBorderWidth
                        }
                        
                        logger.debug("Approximated target - \(approximatedTarget.rownd_metadata.json!)")
                    }
                }
            }
        }
    }
}

extension UIWindow {
    @objc func _swizzled_didAddSubview(_ subview: UIView) {
//        let debouncer = Debouncer()
//        debouncer.debounce(interval: 0.2) {
//            Rownd.automationsCoordinator.processAutomations()
//        }
        
//        let sel = #selector(self._swizzled_didAddSubview(_:))
//        let originalMethod = class_getInstanceMethod(UIWindow.self, sel)
//        if let _ = originalMethod {
//            self._swizzled_didAddSubview(subview)
//        }
    }
}

class Observer {
    static let shared = Observer()

    private init() {}

    func startObservingLayoutChanges() {
        struct MethodMap {
            var original: Method?
            var swizzled: Method?
        }
        var swizzles: [MethodMap] = []
        
        // Swizzle UIApplication.sendEvent for the automations observer to catch
        var originalSelector = #selector(UIApplication.self.sendEvent)
        var swizzledSelector = #selector(UIApplication.self._swizzled_sendEvent(_:))
        var originalMethod = class_getInstanceMethod(UIApplication.self, originalSelector)
        var swizzledMethod = class_getInstanceMethod(UIApplication.self, swizzledSelector)
        swizzles.append(MethodMap(original: originalMethod, swizzled: swizzledMethod))
        
        // Swizzle UIWindow.didAddSubview for the automations observer to catch
        originalSelector = #selector(UIWindow.didAddSubview(_:))
        swizzledSelector = #selector(UIWindow._swizzled_didAddSubview(_:))
        originalMethod = class_getInstanceMethod(UIWindow.self, originalSelector)
        swizzledMethod = class_getInstanceMethod(UIWindow.self, swizzledSelector)
        swizzles.append(MethodMap(original: originalMethod, swizzled: swizzledMethod))
                
        swizzles.forEach {
            if let originalMethod = $0.original, let swizzledMethod = $0.swizzled {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
        }

        // Add observers for layout changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(viewWillLayoutSubviews),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(viewDidLayoutSubviews),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }

    @objc func viewWillLayoutSubviews() {
        // Called just before the layout of the view hierarchy
        print("ApplicationObserver will layout subviews")

        // You can perform actions or notify observers here
    }

    @objc func viewDidLayoutSubviews() {
        // Called after the layout of the view hierarchy
        print("ApplicationObserver did layout subviews")

        // You can perform actions or notify observers here
    }
}
