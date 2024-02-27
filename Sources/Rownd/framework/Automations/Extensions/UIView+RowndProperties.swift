//
//  UIView+RowndProperties.swift
//
//
//  Created by Bobby Radford on 1/24/24.
//

import Foundation
import AnyCodable
import SwiftUI

internal extension UIView {
    
    var rownd_parentViewController: UIViewController? {
        // Starts from next (As we know self is not a UIViewController).
        var parentResponder: UIResponder? = self.next
        while parentResponder != nil {
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
            if let view = parentResponder as? UIView {
                return view.rownd_parentViewController
            }
            parentResponder = parentResponder?.next
        }
        return nil
    }
    
    var rownd_textFromView: String? {
        if let label = self as? UILabel {
            if let text = label.text {
                return text
            }
        }
        if let textField = self as? UITextField {
            if let text = textField.text {
                return text
            }
        }
        if let button = self as? UIButton {
            if let text = button.title(for: .normal) {
                return text
            }
            if #available(iOS 15.0, *) {
                if let subtitle = button.subtitleLabel {
                    return subtitle.text
                }
            }
        }
        if let cell = self as? UITableViewCell {
            if let label = cell.textLabel {
                return label.text
            }
        }
        
        if let segmentControl = self as? UISegmentedControl {
            // TODO: Not sure what to do here
            if let text = segmentControl.titleForSegment(at: segmentControl.selectedSegmentIndex) {
                return text
            }
        }
        
        if self.rownd_isSwiftUIView {
            return self.rownd_textFromSwiftUIView
        }
        
        return nil
    }

    var rownd_textFromSubviews: [String] {
        var texts = [String]()
        
        if let text = self.rownd_textFromView {
            texts.append(text)
        }
        
        for subview in self.subviews {
            texts.append(contentsOf: subview.rownd_textFromSubviews)
        }
        
        return texts
    }
    
    var rownd_textFromSwiftUIView: String? {
        if !self.rownd_isSwiftUIView {
            return nil
        }
        
        return self.rownd_accessibilityLabel
    }
    
    var rownd_isSwiftUIView: Bool {
        guard let hostingController = self.rownd_parentViewController else {
            return false
        }
        guard let hostingControllerView = hostingController.view else {
            return false
        }
        if String(describing: type(of: hostingControllerView)).starts(with: "_UIHostingView") {
            return true
        }
        return false
    }
    
    var rownd_isClickableView: Bool {
        return false
    }

    var rownd_superClassHierarchy: [String] {
        var hierarchy: [String] = [NSStringFromClass(type(of: self))]
        var clz: AnyClass? = type(of: self)
        repeat {
            if let _clz = clz?.superclass() {
                if _clz == UIResponder.self {
                    break
                }
                clz = _clz
                hierarchy.append(NSStringFromClass(_clz))
            } else {
                clz = nil
            }
        } while (clz != nil)
        
        return hierarchy
    }
    
    var rownd_accessibilityLabel: String? {
        if !self.rownd_isSwiftUIView {
            return self.accessibilityLabel
        }
        
        let attributes = RowndAutoHelper.extractAccessibilityAttributesFrom(swiftUIView: self)
        return attributes?.label
    }
    
    var rownd_accessibilityIdentifier: String? {
        if !self.rownd_isSwiftUIView {
            return self.accessibilityIdentifier
        }
        
        let attributes = RowndAutoHelper.extractAccessibilityAttributesFrom(swiftUIView: self)
        return attributes?.identifier
    }
    
    var rownd_descriptiveText: String? {
        return rownd_textFromView
    }
    
    var rownd_metadata: UIViewMetadata {
        let currentClass = String(describing: type(of: self))
        let predicate = "[\(currentClass)]"
        let position = Position(
            top: self.frame.minY,
            width: self.frame.width,
            left: self.frame.minX,
            height: self.frame.height
        )
        var viewController: String? = nil
        if let vc = self.rownd_parentViewController {
            viewController = String(describing: type(of: vc))
        }
        
        let descriptiveTextBase64 = (rownd_descriptiveText != nil) ? rownd_descriptiveText!.data(using: .utf8)?.base64EncodedString() : nil
        
        let retroElementTextsAccessibility = RetroElementTextsAccessibility(
            labelBase64: (rownd_accessibilityLabel != nil) ? rownd_accessibilityLabel!.data(using: .utf8)?.base64EncodedString() : nil,
            identifierBase64: (rownd_accessibilityIdentifier != nil) ? rownd_accessibilityIdentifier!.data(using: .utf8)?.base64EncodedString() : nil
        )
        
        let retroElementTexts = RetroElementTexts(
            accessibility: retroElementTextsAccessibility
        )
        
        return UIViewMetadata(
            textBase64: nil,
            position: position,
            clickable: self.rownd_isClickableView,
            type: "view",
            sections: nil,
            descriptiveTextBase64: descriptiveTextBase64,
            imgWidth: nil,
            retroElementTexts: retroElementTexts,
            imgHeight: nil,
            retroElementCompatibilityHashes: nil,
            zIndex: -1,
            classHierarchy: self.rownd_superClassHierarchy,
            screenStateRef: nil,
            retroElementInfo: RetroElementInfo(
                superClass: String(describing: type(of: self.next!)),
                triggeredByCode: -1,
                currentClass: currentClass,
                predicate: predicate,
                viewController: viewController,
                viewTag: self.tag,
                indexInParent: -1,
                hasGestures: (self.gestureRecognizers ?? []).count,
                accessibility: AccessibilityData(
                    label: rownd_accessibilityLabel
                )
            )
        )
    }
}

internal struct UIViewMetadata: Codable {
    var textBase64: String?
    var position: Position
    var clickable: Bool
    var type: String
    var sections: [AnyCodable]?
    var descriptiveTextBase64: String?
    var imgWidth: Int?
    var retroElementTexts: RetroElementTexts?
    var imgHeight: Int?
    var retroElementCompatibilityHashes: [String]?
    var zIndex: Int
    var classHierarchy: [String]
    var screenStateRef: AnyCodable?
    var retroElementInfo: RetroElementInfo
    
    // We are using this custom encoding function so that nil values show up as null in JSON encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(textBase64, forKey: .textBase64)
        try container.encode(position, forKey: .position)
        try container.encode(clickable, forKey: .clickable)
        try container.encode(type, forKey: .type)
        try container.encode(sections, forKey: .sections)
        try container.encode(descriptiveTextBase64, forKey: .descriptiveTextBase64)
        try container.encode(imgWidth, forKey: .imgWidth)
        try container.encode(retroElementTexts, forKey: .retroElementTexts)
        try container.encode(imgHeight, forKey: .imgHeight)
        try container.encode(retroElementCompatibilityHashes, forKey: .retroElementCompatibilityHashes)
        try container.encode(zIndex, forKey: .zIndex)
        try container.encode(classHierarchy, forKey: .classHierarchy)
        try container.encode(screenStateRef, forKey: .screenStateRef)
        try container.encode(retroElementInfo, forKey: .retroElementInfo)
    }
    
    var json: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(self)
            let jsonString = String(data: jsonData, encoding: .utf8)
            return jsonString
        } catch {
            return nil
        }
    }
}

internal struct AccessibilityData: Codable {
    var label: String?
}

internal struct Position: Codable {
    var top: CGFloat
    var width: CGFloat
    var left: CGFloat
    var height: CGFloat
}

internal struct RetroElementTexts: Codable {
    var accessibility: RetroElementTextsAccessibility?
}

internal struct RetroElementTextsAccessibility: Codable {
    var labelBase64: String?
    var identifierBase64: String?
}

internal struct RetroElementInfo: Codable {
    var superClass: String?
    var triggeredByCode: Int?
    var currentClass: String
    var predicate: String
    var viewController: String?
    var viewTag: Int?
    var indexInParent: Int?
    var hasGestures: Int?
    var accessibility: AccessibilityData?
}
