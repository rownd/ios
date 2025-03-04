//  Copyright © 2021 Lunabee Studio
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  BottomSheetController.swift
//  LBBottomSheet
//
//  Created by Lunabee Studio / Date - 12/10/2021 - for the LBBottomSheet Swift Package.
//

import UIKit

/// This class is the main component of this package.
/// It is presented modally and embeds the controller you want to present as a bottom sheet.
public final class BottomSheetController: UIViewController {
    override public var modalPresentationStyle: UIModalPresentationStyle {
        get { .overFullScreen }
        set { }
    }
    
    /// This is the height of the grabber "zone".
    /// ![TopInset](TopInset)
    ///
    /// Here is it's implementation:
    /// ```swift
    /// public var topInset: CGFloat { (theme.grabber?.topMargin ?? 0.0) * 2.0 + (theme.grabber?.size.height ?? 0.0) }
    /// ```
    /// You can have a look at <doc:/LBBottomSheet/BottomSheetController/Theme-swift.struct/Grabber-swift.struct> to check the <doc:/LBBottomSheet/BottomSheetController/Theme-swift.struct/Grabber-swift.struct/topMargin>.
    public var topInset: CGFloat { (theme.grabber?.topMargin ?? 0.0) * 2.0 + (theme.grabber?.size.height ?? 0.0) }
    
    /// The delegate to get the bottom sheet position updates if the presenting controller needs to update its content bottom inset.
    public weak var bottomSheetPositionDelegate: BottomSheetPositionDelegate? {
        didSet { notifyBottomSheetPositionUpdate() }
    }
    /// The delegate to get bottom sheet interactions events.
    public weak var bottomSheetInteractionDelegate: BottomSheetInteractionDelegate?
    
    @IBOutlet private var mainDismissButton: UIButton!
    @IBOutlet private var grabberView: UIView!
    @IBOutlet private var gestureView: UIView!
    @IBOutlet private var topGrabberConstraint: NSLayoutConstraint!
    @IBOutlet private var widthGrabberConstraint: NSLayoutConstraint!
    @IBOutlet private var heightGrabberConstraint: NSLayoutConstraint!
    @IBOutlet private var bottomContainerView: UIView!
    @IBOutlet private var bottomContainerInnerView: UIView!
    @IBOutlet private var bottomContainerInnerViewTranslucentTopConstraint: NSLayoutConstraint!
    @IBOutlet private var bottomContainerInnerViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private var bottomContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var bottomContainerBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var bottomContainerLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private var bottomContainerTrailingConstraint: NSLayoutConstraint!
    
    public private(set) var theme: Theme = Theme()
    public private(set) var behavior: Behavior = Behavior()
    private let minTopMargin: CGFloat = 40.0
    private var didAlreadyStartAppearing: Bool = false
    
    private var panGesture: UIPanGestureRecognizer?
    private var tapGesture: UITapGestureRecognizer?
    private var isGestureBeingActivated: Bool = false
    private var lastHeightAtPanGestureStart: CGFloat = 0.0
    private var lastChildHeightAtPanGestureStart: CGFloat = 0.0
    private var bottomSheetChild: UIViewController!
    private var isChildAlreadyVisible: Bool = false
    private var childHeight: CGFloat {
        if let heightDeclaringController = bottomSheetChild.lbbsFindControllerDeclaringPreferredHeightInBottomSheet() {
            var height: CGFloat = heightDeclaringController.value(forKey: BottomSheetConstant.preferredHeightVariableName) as? CGFloat ?? 0.0
            if let grabber = theme.grabber, !grabber.background.isTranslucent { height += topInset }
            return height
        } else {
            print("⚠️ [LBBottomSheet] ⚠️: If you use the \"fitContent\" heightMode, you can declare the following variable in the controller you want to present: \"@objc var preferredHeightInBottomSheet: CGFloat\" returning the customized height you want the bottom sheet to have.")
            let childView: UIView? = bottomSheetChild?.view
            let defaultFirstScrollView: UIScrollView? = childView?.lbbsGetFirstTableOrCollectionView()
            let defaultHeight: CGFloat = defaultFirstScrollView?.lbbsContentHeight ?? childView?.frame.height ?? 0.0
            if defaultHeight == 0.0 {
                print("👉 [LBBottomSheet]: The default calculated height is 0.0 so the applied height is by default 75% of the screen height.")
                return UIScreen.main.bounds.height * 0.75
            } else {
                print("👉 [LBBottomSheet]: The default calculated height is \(defaultHeight) based on your layout. You can have a look at the previous warning log to customize this behavior.")
                let bottomSafeArea: CGFloat = UIApplication.shared.lbbsKeySceneWindow?.safeAreaInsets.bottom ?? 0.0
                var height: CGFloat = defaultHeight + bottomSafeArea
                if let grabber = theme.grabber, !grabber.background.isTranslucent { height += topInset }
                return height
            }
        }
    }
    private var isFirstLoad: Bool = true
    
    /// Overriden to customize the way the controller is initialized.
    public override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
        initGrabberBackgroundView()
        addGesture()
        addObservers()
    }
    
    /// Overriden to customize the way the controller is appearing.
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard isFirstLoad else { return }
        isFirstLoad = false
        preferredHeightInBottomSheetDidUpdate()
        setInitialPosition()
        setupDimmingBackground()
        makeAppearing()
    }
    
    public func setCanTouchDimmingBackgroundToDismiss(_ enable: Bool) {
        behavior.canTouchDimmingBackgroundToDismiss = enable
        behavior.allowsSwipeToDismiss = enable
    }
    
    /// Call this function to tell the bottom sheet the embedded controller height did change.
    /// This way, this controller will calculate the new needed height and the bottom sheet layout will be updated.
    public func preferredHeightInBottomSheetDidUpdate() {
        // Ensure view and IBOutlet are loaded
        guard isViewLoaded, let constraint = bottomContainerHeightConstraint else { return }

            panGesture?.lbbsCancel()

            let newHeight: CGFloat = calculateExpectedHeight()
            guard newHeight != constraint.constant else { return }

            constraint.constant = newHeight

            if didAlreadyStartAppearing {
                animate { [weak self] in
                    self?.view?.layoutIfNeeded()
                }
            } else {
                view.layoutIfNeeded()
            }
    }
    
    /// Overriden to update the shadow color in case of light/dark mode change.
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateShadowColors()
    }
    
    /// Overriden to call the position delegate update method after a layout calculation.
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        notifyBottomSheetPositionUpdate()
    }
    
    /// Use this function to dismiss the bottom sheet. This will animate the disappearing based on the behavior configuration.
    public func dismiss(_ completion: (() -> Void)? = nil) {
        guard isViewLoaded, view.window != nil else {
            super.dismiss(animated: false, completion: completion)
            return
        }

        makeDisappearing {
            super.dismiss(animated: false, completion: completion)
        }
    }
    
    @available(swift, obsoleted: 5.0, message: "Use the bottom sheet provided dismiss function instead of the default one.", renamed: "dismiss(_:)")
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
    }
    
    public func grow(toMaximumHeight: Bool = false) {
        switch behavior.heightMode {
        case .specific:
            let childHeight: CGFloat = childHeight
            let screenHeight: CGFloat = UIScreen.main.bounds.height
            let maximumHeight: CGFloat = behavior.heightMode.maximumHeight(with: childHeight, screenHeight: screenHeight, from: self)
            let nextHeight: CGFloat? = behavior.heightMode.nextHeight(with: childHeight,
                                                                      screenHeight: maximumHeight,
                                                                      from: self,
                                                                      originHeight: bottomContainerHeightConstraint.constant,
                                                                      goingUp: true)
            guard let destinationHeight = toMaximumHeight ? maximumHeight : nextHeight else { return }
            bottomContainerHeightConstraint.constant = destinationHeight
            bottomContainerBottomConstraint.constant = 0.0
            animate {
                self.updateCornerRadiusFor(destinationHeight: destinationHeight)
                self.view.layoutIfNeeded()
            }
        default:
            print("⚠️ [LBBottomSheet] ⚠️: Call to grow(toMaximumHeight:) doesn't have any effect as the current HeightMode is not `.specific`")
            break
        }
    }
    
    public func reduce(toMinimumHeight: Bool = false) {
        switch behavior.heightMode {
        case .specific:
            let childHeight: CGFloat = childHeight
            let screenHeight: CGFloat = UIScreen.main.bounds.height
            let minimumHeight: CGFloat = behavior.heightMode.minimumHeight(with: childHeight, screenHeight: screenHeight)
            let nextHeight: CGFloat? = behavior.heightMode.nextHeight(with: childHeight,
                                                                      screenHeight: UIScreen.main.bounds.height,
                                                                      from: self,
                                                                      originHeight: bottomContainerHeightConstraint.constant,
                                                                      goingUp: false)
            guard let destinationHeight = toMinimumHeight ? minimumHeight : nextHeight else { return }
            bottomContainerHeightConstraint.constant = destinationHeight
            bottomContainerBottomConstraint.constant = 0.0
            animate {
                self.updateCornerRadiusFor(destinationHeight: destinationHeight)
                self.view.layoutIfNeeded()
            }
        default:
            print("⚠️ [LBBottomSheet] ⚠️: Call to reduce(toMinimumHeight:) doesn't have any effect as the current HeightMode is not `.specific`")
            break
        }
    }
}

// MARK: - Controller instantiation -
internal extension BottomSheetController {
    static func controller(bottomSheetChild: UIViewController,
                           bottomSheetPositionDelegate: BottomSheetPositionDelegate? = nil,
                           bottomSheetInteractionDelegate: BottomSheetInteractionDelegate? = nil,
                           theme: Theme = Theme(),
                           behavior: Behavior = Behavior()) -> BottomSheetController {
        let bottomController: BottomSheetController = UIStoryboard(name: "BottomSheet", bundle: Bundle.module).instantiateInitialViewController() as! BottomSheetController
        bottomController.bottomSheetChild = bottomSheetChild
        bottomController.bottomSheetPositionDelegate = bottomSheetPositionDelegate
        bottomController.bottomSheetInteractionDelegate = bottomSheetInteractionDelegate
        bottomController.theme = theme
        bottomController.behavior = behavior
        return bottomController
    }
}

// MARK: - UI configuration -
private extension BottomSheetController {
    func initUI() {
        view.backgroundColor = .clear
        bottomContainerView.backgroundColor = .clear
        bottomContainerView.layer.cornerRadius = theme.cornerRadius
        bottomContainerView.layer.maskedCorners = theme.maskedCorners
        bottomContainerView.layer.masksToBounds = true
        bottomContainerView.alpha = 0.0
        
        if let grabber = theme.grabber {
            topGrabberConstraint.constant = grabber.topMargin
            widthGrabberConstraint.constant = grabber.size.width
            heightGrabberConstraint.constant = grabber.size.height
            grabberView.backgroundColor = grabber.color
            grabberView.layer.maskedCorners = grabber.maskedCorners
            grabberView.layer.masksToBounds = true
            switch grabber.cornerRadiusType {
            case .rounded:
                grabberView.layer.cornerRadius = grabber.size.height / 2.0
            case let .fixed(value):
                grabberView.layer.cornerRadius = value
            }
        } else {
            grabberView.isHidden = true
        }
        
        if let shadow = theme.shadow {
            updateShadowColors()
            view.layer.shadowOffset = shadow.offset
            view.layer.shadowOpacity = shadow.opacity
            view.layer.shadowRadius = shadow.radius
            view.layer.shouldRasterize = true
            view.layer.rasterizationScale = UIScreen.main.scale
        }
        
        lbbsAddChildViewController(bottomSheetChild, containerView: bottomContainerInnerView)
        bottomContainerView.backgroundColor = bottomSheetChild.view.backgroundColor
        bottomContainerLeadingConstraint.constant = theme.leadingMargin
        bottomContainerTrailingConstraint.constant = theme.trailingMargin
    }
    
    func initGrabberBackgroundView() {
        guard let background = theme.grabber?.background else { return }
        switch background {
        case let .color(color, isTranslucent):
            let coloredView: UIView = UIView()
            coloredView.backgroundColor = color
            gestureView.lbbsAddFullSubview(coloredView, belowSubview: grabberView)
            updateBottomChildContainerTopConstraint(isGrabberBackgroundTranslucent: isTranslucent)
        case let .view(view, isTranslucent):
            gestureView.lbbsAddFullSubview(view, belowSubview: grabberView)
            updateBottomChildContainerTopConstraint(isGrabberBackgroundTranslucent: isTranslucent)
        }
    }
    
    func updateShadowColors() {
        guard let color = theme.shadow?.color.cgColor else { return }
        view.layer.shadowColor = color
    }
    
    func updateBottomChildContainerTopConstraint(isGrabberBackgroundTranslucent: Bool) {
        bottomContainerInnerViewTranslucentTopConstraint.isActive = isGrabberBackgroundTranslucent
        bottomContainerInnerViewTopConstraint.isActive = !isGrabberBackgroundTranslucent
    }
    
    func setInitialPosition() {
        bottomContainerBottomConstraint.constant = -calculateExpectedHeight()
        bottomContainerView.alpha = 1.0
        view.layoutIfNeeded()
    }
    
    func setupDimmingBackground() {
        if behavior.forwardEventsToRearController {
            mainDismissButton.isUserInteractionEnabled = false
            if let rearView = presentingViewController?.view {
                let view: ForwardingEventsView = self.view as! ForwardingEventsView
                view.destinationView = rearView
                view.excludedParentView = bottomContainerView
            }
        } else {
            mainDismissButton.isUserInteractionEnabled = true
        }
    }
    
    func addGesture() {
        guard behavior.swipeMode != .none else { return }
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognizerHandler(_:)))
        panGesture?.delegate = self
        view.addGestureRecognizer(panGesture!)
        if theme.grabber?.canTouchToDismiss == true {
            tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognizerHandler(_:)))
            tapGesture?.delegate = self
            view.addGestureRecognizer(tapGesture!)
        }
    }
}

// MARK: - Observers -
private extension BottomSheetController {
    func addObservers() {
        guard behavior.updateHeightOnContentSizeCategoryChange else { return }
        NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.bottomContainerView?.layoutIfNeeded()
            self?.preferredHeightInBottomSheetDidUpdate()
        }
    }
}

// MARK: - Appearing/Disappearing animations -
private extension BottomSheetController {
    func makeAppearing() {
        didAlreadyStartAppearing = true
        bottomContainerHeightConstraint.constant = calculateExpectedHeight()
        bottomContainerBottomConstraint.constant = 0.0
        animateAppearing {
            self.view.backgroundColor = self.theme.dimmingBackgroundColor
            self.view.layoutIfNeeded()
        }
    }
    
    func makeDisappearing(_ completion: @escaping () -> ()) {
        bottomContainerBottomConstraint.constant = -bottomContainerHeightConstraint.constant
        animateDisappearing { [weak self] in
            self?.view.backgroundColor = .clear
            self?.view.layoutIfNeeded()
        } completion: {
            completion()
        }
    }
}

// MARK: - BottomSheet position update -
private extension BottomSheetController {
    func notifyBottomSheetPositionUpdate() {
        guard isViewLoaded else { return }
        bottomSheetPositionDelegate?.bottomSheetPositionDidUpdate(y: UIScreen.main.bounds.height - bottomContainerHeightConstraint.constant - bottomContainerBottomConstraint.constant)
    }
}

// MARK: - Pan gesture management -
private extension BottomSheetController {
    @objc func panGestureRecognizerHandler(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            processPanGestureBegan(gesture)
            fallthrough
        case .changed:
            processPanGestureChanged(gesture)
        case .ended, .cancelled, .failed:
            processPanGestureEnded(gesture)
        default:
            break
        }
    }
    
    func processPanGestureBegan(_ gesture: UIPanGestureRecognizer) {
        tapGesture?.lbbsCancel()
        isGestureBeingActivated = true
        lastHeightAtPanGestureStart = bottomContainerHeightConstraint.constant
        lastChildHeightAtPanGestureStart = childHeight
    }
    
    func processPanGestureChanged(_ gesture: UIPanGestureRecognizer) {
        let yTranslation: CGFloat = gesture.translation(in: bottomContainerView).y
        let destinationHeight: CGFloat = lastHeightAtPanGestureStart - yTranslation
        let childHeight: CGFloat = lastChildHeightAtPanGestureStart
        let newHeight: CGFloat
        let newBottom: CGFloat
        let minHeight: CGFloat = behavior.heightMode.minimumHeight(with: childHeight, screenHeight: UIScreen.main.bounds.height)
        let maxHeight: CGFloat = behavior.heightMode.maximumHeight(with: childHeight, screenHeight: UIScreen.main.bounds.height, from: self)
        if destinationHeight > maxHeight {
            newHeight = maxHeight + behavior.elasticityFunction(destinationHeight - maxHeight)
            newBottom = 0.0
        } else if destinationHeight < minHeight {
            newHeight = minHeight
            newBottom = behavior.allowsSwipeToDismiss ? destinationHeight - minHeight : -behavior.elasticityFunction(abs(destinationHeight - minHeight))
        } else {
            newHeight = destinationHeight
            newBottom = 0.0
        }
        bottomContainerHeightConstraint.constant = newHeight
        bottomContainerBottomConstraint.constant = newBottom
        view.layoutIfNeeded()
    }
    
    func processPanGestureEnded(_ gesture: UIPanGestureRecognizer) {
        let yTranslation: CGFloat = gesture.translation(in: bottomContainerView).y
        let yVelocity: CGFloat = gesture.velocity(in: bottomContainerView).y
        if (yTranslation > lastHeightAtPanGestureStart * behavior.heightPercentageThresholdToDismiss || yVelocity > behavior.velocityThresholdToDismiss) {

            switch behavior.heightMode {
            case .specific:
                if behavior.allowsSwipeToDismiss {
                    dismiss()
                } else {
                    bottomContainerHeightConstraint.constant = behavior.heightMode.minimumHeight(with: lastChildHeightAtPanGestureStart,
                                                                                                 screenHeight: UIScreen.main.bounds.height)
                    bottomContainerBottomConstraint.constant = 0.0
                    animate { self.view.layoutIfNeeded() }
                }
            default:
                if behavior.allowsSwipeToDismiss {
                    dismiss()
                } else {
                    bottomContainerHeightConstraint.constant = behavior.heightMode.minimumHeight(with: lastChildHeightAtPanGestureStart,
                                                                                                 screenHeight: UIScreen.main.bounds.height)
                    bottomContainerBottomConstraint.constant = 0.0
                    animate { self.view.layoutIfNeeded() }
                }
            }
        } else {
            switch behavior.heightMode {
            case .specific:
                let isFastSwipeUpGestureDetected: Bool = yVelocity < -behavior.velocityThresholdToOpenAtMaxHeight
                let maximumHeight: CGFloat = behavior.heightMode.maximumHeight(with: lastChildHeightAtPanGestureStart,
                                                                              screenHeight: UIScreen.main.bounds.height,
                                                                              from: self)
                let expectedHeight: CGFloat = calculateExpectedHeight(lastChildHeightAtPanGestureStart)

                let destinationHeight: CGFloat = isFastSwipeUpGestureDetected ? maximumHeight : expectedHeight
                bottomContainerHeightConstraint.constant = destinationHeight
                bottomContainerBottomConstraint.constant = 0.0
                animate {
                    self.updateCornerRadiusFor(destinationHeight: destinationHeight)
                    self.view.layoutIfNeeded()
                }
            default:
                let destinationHeight: CGFloat = calculateExpectedHeight(lastChildHeightAtPanGestureStart)
                bottomContainerHeightConstraint.constant = destinationHeight
                bottomContainerBottomConstraint.constant = 0.0
                animate { self.view.layoutIfNeeded() }
            }
        }
        isGestureBeingActivated = false
    }
    
    func calculateExpectedHeight(_ givenChildHeight: CGFloat? = nil) -> CGFloat {
        let childHeight: CGFloat = givenChildHeight ?? self.childHeight
        switch behavior.heightMode {
        case let .fitContent(heightLimit):
            return min(childHeight, heightLimit.value(from: self, screenHeight: UIScreen.main.bounds.height))
        case let .free(minHeight, maxHeight, heightLimit):
            let maxHeightLimit: CGFloat = heightLimit.value(from: self, screenHeight: UIScreen.main.bounds.height)
            return min(max(bottomContainerHeightConstraint.constant, minHeight ?? 0.0), min(maxHeight ?? maxHeightLimit, maxHeightLimit))
        case let .specific(values, heightLimit):
            let maxHeightLimit: CGFloat = heightLimit.value(from: self, screenHeight: UIScreen.main.bounds.height)
            let heightValues: [CGFloat] = values.sortedPointValues(screenHeight: UIScreen.main.bounds.height, childHeight: childHeight)
                                                .map { min($0, maxHeightLimit) }
            return min(heightValues.min { abs($0 - bottomContainerHeightConstraint.constant) < abs($1 - bottomContainerHeightConstraint.constant) } ?? 0.0, maxHeightLimit)
        }
    }
    
    func updateCornerRadiusFor(destinationHeight: CGFloat) {
        bottomContainerView.layer.cornerRadius = destinationHeight == UIScreen.main.bounds.height ? UIScreen.main.lbbsCornerRadius : theme.cornerRadius
    }
}

// MARK: - Tap gesture management -
private extension BottomSheetController {
    @objc func tapGestureRecognizerHandler(_ gesture: UITapGestureRecognizer) {
        switch gesture.state {
        case .ended:
            dismiss()
        default:
            break
        }
    }
}

// MARK: - Gestures delegates -
extension BottomSheetController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === tapGesture {
            return gestureView.bounds.contains(gestureRecognizer.location(in: gestureView))
        } else if gestureRecognizer === panGesture {
            switch behavior.swipeMode {
            case .top:
                return gestureView.bounds.contains(gestureRecognizer.location(in: gestureView))
            case .full:
                return bottomContainerView!.bounds.contains(gestureRecognizer.location(in: bottomContainerView))
            default:
                return false
            }
        } else {
            return true
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGesture = panGesture, gestureRecognizer === panGesture {
            if let scrollView = otherGestureRecognizer.view as? UIScrollView {
                // In the case the user is swiping down, we have to check if we let the contained scrollView scrolling or if we have
                // to cancel the scrollView gesture to let the bottomSheet itself being swiped.
                let isSwipingFromGestureView: Bool = gestureView.frame.contains(gestureRecognizer.location(in: gestureView))
                let isTheMainEmbeddedViewAScrollView: Bool = scrollView.superview?.subviews.count == 1
                let isScrollViewAtTheTop: Bool = scrollView.contentOffset.y <= 0.0
                let isUserSwipingDown: Bool = panGesture.translation(in: view).y >= 0.0
                if isSwipingFromGestureView || (isTheMainEmbeddedViewAScrollView && isScrollViewAtTheTop && isUserSwipingDown && behavior.swipeMode == .full) {
                    otherGestureRecognizer.lbbsCancel()
                    scrollView.setContentOffset(.zero, animated: true)
                    return true
                } else {
                    return false
                }
            } else {
                return true
            }
        } else {
            return true
        }
    }
}

// MARK: - Animation -
private extension BottomSheetController {
    func animate(_ block: @escaping () -> ()) {
        if let animationConfiguration = behavior.bottomSheetAnimationConfiguration {
            UIView.animate(withDuration: animationConfiguration.duration,
                           delay: 0.0,
                           usingSpringWithDamping: animationConfiguration.damping,
                           initialSpringVelocity: animationConfiguration.velocity,
                           options: [.curveEaseInOut]) {
                block()
            }
        } else {
            UIView.animate(withDuration: 0.3) { block() }
        }
    }

    func animateAppearing(_ block: @escaping () -> ()) {
        if let animationConfiguration = behavior.appearingAnimationConfiguration {
            UIView.animate(withDuration: animationConfiguration.duration,
                           delay: 0.0,
                           usingSpringWithDamping: animationConfiguration.damping,
                           initialSpringVelocity: animationConfiguration.velocity,
                           options: [.curveEaseInOut],
                           animations: { block() })
        } else {
            UIView.animate(withDuration: 0.5,
                           delay: 0.0,
                           usingSpringWithDamping: 1.0,
                           initialSpringVelocity: 0.1,
                           options: [.curveEaseOut],
                           animations: { block() })
        }
    }

    func animateDisappearing(_ animationBlock: @escaping () -> (), completion: @escaping () -> ()) {
        if let animationConfiguration = behavior.disappearingAnimationConfiguration {
            UIView.animate(withDuration: animationConfiguration.duration,
                           delay: 0.0,
                           usingSpringWithDamping: animationConfiguration.damping,
                           initialSpringVelocity: animationConfiguration.velocity,
                           options: [.curveEaseInOut],
                           animations: { animationBlock() }) { _ in
                completion()
            }
        } else {
            UIView.animate(withDuration: 0.5,
                           delay: 0.0,
                           usingSpringWithDamping: 1.0,
                           initialSpringVelocity: 0.1,
                           options: [.curveEaseOut],
                           animations: { animationBlock() }) { _ in
                completion()
            }
        }
    }

    func vibrateBottomSheet() {
        guard let bottomSheetView = self.bottomContainerView else {
            return
        }

        let originalY = bottomSheetView.frame.origin.y
        let offset: CGFloat = 10  // The amount to move up and down

        UIView.animateKeyframes(withDuration: 0.3, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.25) {
                bottomSheetView.frame.origin.y = originalY - offset
            }
            UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                bottomSheetView.frame.origin.y = originalY + offset
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.25) {
                bottomSheetView.frame.origin.y = originalY - (offset / 2)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                bottomSheetView.frame.origin.y = originalY
            }
        })
    }
}

// MARK: - Actions -
private extension BottomSheetController {
    @IBAction func dismissButtonPressed(_ sender: Any) {
        bottomSheetInteractionDelegate?.bottomSheetInteractionDidTapOutside()
        if !behavior.canTouchDimmingBackgroundToDismiss {
            vibrateBottomSheet()
            return
        }

        dismiss()
    }
}
