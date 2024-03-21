//
//  View+SetRowndID.swift
//
//
//  Created by Bobby Radford on 3/20/24.
//

import Foundation
import SwiftUI

extension View {
    public func rowndSetID(_ id: String) -> some View {
        if let _self = self as? UIView {
            if _self.rownd_isSwiftUIView {
                let a11yElement = UIAccessibilityElement()
                a11yElement.accessibilityLabel = id
                
                var elements = _self.rownd_parentViewController?.accessibilityElements ?? []
                elements.append(a11yElement)
                _self.rownd_parentViewController?.accessibilityElements = elements
            }
        } else {
            _ = self.accessibilityLabel(id)
        }
        
        
        // I'm not sure if this could cause problems for UIKit yet
        _ = self.id(id)
        
        return self
    }
}
