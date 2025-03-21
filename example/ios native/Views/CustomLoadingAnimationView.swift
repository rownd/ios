import Foundation
import UIKit

class CustomLoadingAnimationView: UIView {

    let animationImageView: UIImageView

    override init(frame: CGRect) {
        animationImageView = UIImageView()
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        animationImageView = UIImageView()
        super.init(coder: aDecoder)
        setup()
    }

    func setup() {
        addSubview(animationImageView)

        // Load animation images
        var images: [UIImage] = []
        for i in 0 ... 40 {
            let suffix = i % 2 == 0 ? 2 : 3
            let name = "frame_\(String(format: "%02d", i))_delay-0.\(String(format: "%02d", suffix))s"
            if let image = UIImage(named: name) {
                images.append(image)
            }
        }

        animationImageView.animationImages = images
        animationImageView.animationRepeatCount = 0 // Infinite loop
        animationImageView.startAnimating()

        animationImageView.contentMode = .scaleAspectFit
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        guard let superview = superview else { return }

        // Enable auto layout
        translatesAutoresizingMaskIntoConstraints = false
        animationImageView.translatesAutoresizingMaskIntoConstraints = false

        // Set constraints to fill the parent container
        NSLayoutConstraint.activate([
            self.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            self.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            self.topAnchor.constraint(equalTo: superview.topAnchor),
            self.bottomAnchor.constraint(equalTo: superview.bottomAnchor)
        ])

        // Calculate relative width based on the height
        let animationHeight: CGFloat = 125
        var animationWidth: CGFloat = animationHeight // Default to a square if no image is available

        if let firstImage = animationImageView.animationImages?.first {
            let aspectRatio = firstImage.size.width / firstImage.size.height
            animationWidth = animationHeight * aspectRatio
        }

        // Set the size of the animationImageView
        NSLayoutConstraint.activate([
            animationImageView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            animationImageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            animationImageView.widthAnchor.constraint(equalToConstant: animationWidth),
            animationImageView.heightAnchor.constraint(equalToConstant: animationHeight)
        ])

        animationImageView.contentMode = .scaleAspectFit
    }
}
