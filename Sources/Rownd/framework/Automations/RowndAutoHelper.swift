//
//  RowndAutoHelper.swift
//
//
//  Created by Bobby Radford on 1/26/24.
//

import Foundation
import UIKit

internal class RowndAutoHelper {
    static func extractTextsFrom(_ view: UIView, into: inout [String]) -> Void {
        let text = view.rownd_textFromSubviews
        into.append(contentsOf: text)
    }
    
    static func extractAccessibilityAttributesFrom(swiftUIView: UIView) -> AccessibilityAttributes? {
        guard let hostingView = swiftUIView.rownd_parentViewController?.view else {
            return nil
        }
                
        guard let accessibilityElements = hostingView.accessibilityElements else {
            return nil
        }
                
        var element: NSObject?
        for _element in accessibilityElements {
            guard let elementNSObject = _element as? NSObject, elementNSObject.isAccessibilityElement else {
                continue
            }
            
            let framesMatch = UIAccessibility.convertToScreenCoordinates(swiftUIView.frame, in: hostingView).isEqual(to: elementNSObject.accessibilityFrame, approximate: true)
            
            if framesMatch {
                element = elementNSObject
                break
            }
        }
                
        guard let element = element else {
            return nil
        }
        
                
        let label = element.value(forKey: "accessibilityLabel") as? String
        let identifier = element.value(forKey: "accessibilityIdentifier") as? String
        
        return AccessibilityAttributes(
            label: label,
            identifier: identifier
        )
    }
}

internal struct AccessibilityAttributes {
    var label: String?
    var identifier: String?
}
