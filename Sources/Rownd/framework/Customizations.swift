//
//  Customizations.swift
//  Rownd
//
//  Created by Matt Hamann on 9/12/22.
//

import Foundation
import SwiftUI

public struct RowndCustomizations: Encodable {
    public init(){}

    public var sheetBackgroundColor: UIColor {
        switch(UIViewController().colorScheme) {
        case .light, .unspecified:
            return .white
        case .dark:
            return .systemGray6
        @unknown default:
            return .white
        }
    }

    public var sheetCornerBorderRadius: CGFloat = CGFloat(25.0)

    public var defaultFontSize: CGFloat = UIFontMetrics(forTextStyle: .body).scaledFont(for: .preferredFont(forTextStyle: .body)).pointSize - 5

    internal enum CodingKeys: String, CodingKey {
        case sheetBackgroundColor
        case sheetCornerBorderRadius
        case defaultFontSize
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sheetCornerBorderRadius, forKey: .sheetCornerBorderRadius)
        try container.encode(defaultFontSize, forKey: .defaultFontSize)
        try container.encode(uiColorToRgbaString(color: sheetBackgroundColor), forKey: .sheetBackgroundColor)
    }
}

fileprivate func uiColorToRgbaString(color: UIColor) -> String {
    let ciColor = CIColor(color: color)
    return String(format: "rgba(%d, %d, %d, %.1f)", Int(round(ciColor.red * 255)), Int(round(ciColor.green * 255)), Int(round(ciColor.blue * 255)), round(ciColor.alpha))
}

extension UIViewController {
    var colorScheme: UIUserInterfaceStyle {
        if #available(iOS 13.0, *) {
            return self.traitCollection.userInterfaceStyle
        }
        else {
            return UIUserInterfaceStyle.unspecified
        }
    }

}
