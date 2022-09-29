//
//  LottieSwiftView.swift
//  Rownd
//
//  Created by Matt Hamann on 9/26/22.
//

import Foundation
import Lottie
import UIKit
import SwiftUI

struct LottieSwiftView: UIViewRepresentable {
    var animation: Lottie.Animation
    var loopMode: LottieLoopMode = .loop

    func makeUIView(context: UIViewRepresentableContext<LottieSwiftView>) -> UIView {
        let view = UIView(frame: .zero)

        let animationView = AnimationView()
        animationView.animation = animation
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.startAnimating()

        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])

        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
    }
}
