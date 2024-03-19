//
//  Customizations.swift
//  Rownd
//
//  Created by Matt Hamann on 9/12/22.
//

import Foundation
import SwiftUI
import Lottie

open class RowndCustomizations: Encodable {
    public init(){}

    open var sheetBackgroundColor: UIColor {
        let darkMode = store.state.appConfig.config?.hub?.customizations?.darkMode
        if (darkMode == "enabled") {
            return BACKGROUND_DARK
        }
        if (darkMode == "disabled") {
            return BACKGROUND_LIGHT
        }
        switch(UIViewController().colorScheme) {
        case .light, .unspecified:
            return BACKGROUND_LIGHT
        case .dark:
            return BACKGROUND_DARK
        @unknown default:
            return BACKGROUND_LIGHT
        }
    }

    open var sheetCornerBorderRadius: CGFloat = CGFloat(25.0)

    open var loadingAnimation: LottieAnimation? = nil

    public var defaultFontSize: CGFloat = UIFontMetrics(forTextStyle: .body).scaledFont(for: .preferredFont(forTextStyle: .body)).pointSize - 5

    internal var loadingAnimationView: LottieAnimationView {
        let aniView = LottieAnimationView(animation: loadingAnimation!)
        aniView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        aniView.contentMode = .scaleAspectFit
        aniView.frame = CGRect.init(
            x: 0,
            y: 0,
            width: 100,
            height: 100
        )

        aniView.loopMode = .loop
        aniView.startAnimating()
        return aniView
    }

    public enum CodingKeys: String, CodingKey {
        case sheetBackgroundColor
        case sheetCornerBorderRadius
        case defaultFontSize
        case fontFamily
        case customStylesFlag
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sheetCornerBorderRadius, forKey: .sheetCornerBorderRadius)
        try container.encode(defaultFontSize, forKey: .defaultFontSize)
        try container.encode(uiColorToRgbaString(color: sheetBackgroundColor), forKey: .sheetBackgroundColor)
        try container.encode(store.state.appConfig.config?.hub?.customizations?.fontFamily, forKey: .fontFamily)
        try container.encode(store.state.appConfig.config?.hub?.customStyles?[safe: 0]?.content.count ?? 0 > 0, forKey: .customStylesFlag)
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

extension LottieAnimationView {

    func startAnimating(_ hideWhenFinished: Bool = true) {
        self.play { finished in
            if hideWhenFinished {
                self.isHidden = true
            }
        }
    }

    func stopAnimating() {
        self.stop()
    }
}
