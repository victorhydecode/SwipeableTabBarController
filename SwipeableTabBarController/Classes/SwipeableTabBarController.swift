//
//  MGSwipeableTabBarController.swift
//  MGSwipeableTabBarController
//
//  Created by Marcos Griselli on 1/26/17.
//  Copyright © 2017 Marcos Griselli. All rights reserved.
//

import UIKit

/// `UITabBarController` subclass with a `selectedViewController` property observer,
/// `SwipeInteractor` that handles the swiping between tabs gesture, and a `SwipeTransitioningProtocol`
/// that determines the animation to be added. Use it or subclass it.
open class SwipeableTabBarController: UITabBarController {

    private var hide = true

    // MARK: - Private API
    fileprivate var swipeInteractor = SwipeInteractor()
    fileprivate var swipeAnimatedTransitioning: SwipeTransitioningProtocol = SwipeAnimation()
    fileprivate var tapAnimatedTransitioning: SwipeTransitioningProtocol = SwipeAnimation()
    fileprivate var currentAnimatedTransitioningType: SwipeTransitioningProtocol = SwipeAnimation()

    private let kSelectedViewControllerKey = "selectedViewController"

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setup()
    }

    private func setup() {
        currentAnimatedTransitioningType = swipeAnimatedTransitioning

        //swipeInteractor.delegate = self
        if #available(iOS 11.0, *) {
            swipeAnimatedTransitioning.start = didStart
            swipeAnimatedTransitioning.finish = didFinish
            tapAnimatedTransitioning.start = didStart
            tapAnimatedTransitioning.finish = didFinish
        } else {
            // Fallback on earlier versions
        }

        // Set the closure for finishing the transition
        swipeInteractor.onfinishTransition = {
            if let controllers = self.viewControllers {
                self.selectedViewController = controllers[self.selectedIndex]
                self.delegate?.tabBarController?(self, didSelect: self.selectedViewController!)
            }
        }

        // UITabBarControllerDelegate for transitions.
        delegate = self

        // Observe selected index changes to wire the gesture recognizer to the viewController.
        addObserver(self, forKeyPath: kSelectedViewControllerKey, options: .new, context: nil)
    }

    // MARK: - Public API

    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        // .selectedViewController changes so we setup the swipe interactor to the new selected Controller.
        if keyPath == kSelectedViewControllerKey {
            if let selectedController = selectedViewController {
                swipeInteractor.wireTo(viewController: selectedController.firstController())
            }
        }
    }

    /// Modify the swipe animation, it can be one of the default `SwipeAnimationType` or your own type
    /// conforming to `SwipeAnimationTypeProtocol`.
    ///
    /// - Parameter type: object conforming to `SwipeAnimationTypeProtocol`.
    open func setSwipeAnimation(type: SwipeAnimationTypeProtocol) {
        swipeAnimatedTransitioning.animationType = type
    }

    /// Modify the swipe animation, it can be one of the default `SwipeAnimationType` or your own type
    /// conforming to `SwipeAnimationTypeProtocol`.
    ///
    /// - Parameter type: object conforming to `SwipeAnimationTypeProtocol`.
    open func setTapAnimation(type: SwipeAnimationTypeProtocol) {
        tapAnimatedTransitioning.animationType = type
    }

    /// Modify the transitioning animation.
    ///
    /// - Parameter animation: UIViewControllerAnimatedTransitioning conforming to
    /// `SwipeTransitioningProtocol`.
    open func setAnimationTransitioning(animation: SwipeTransitioningProtocol) {
        swipeAnimatedTransitioning = animation
    }

    /// Toggle the diagonal swipe to remove the just `perfect` horizontal swipe interaction
    /// needed to perform the transition.
    ///
    /// - Parameter enabled: Bool value to the corresponding diagnoal swipe support.
    open func setDiagonalSwipe(enabled: Bool) {
        swipeInteractor.isDiagonalSwipeEnabled = enabled
    }

    /// Enables/Disables swipes on the tabbar controller.
    open var isSwipeEnabled = true {
        didSet { swipeInteractor.isEnabled = isSwipeEnabled }
    }
}

// MARK: - UITabBarControllerDelegate
extension SwipeableTabBarController: UITabBarControllerDelegate {

    public func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {

        // Get the indexes of the ViewControllers involved in the animation to determine the animation flow.
        guard let fromVCIndex = tabBarController.viewControllers?.index(of: fromVC),
            let toVCIndex   = tabBarController.viewControllers?.index(of: toVC) else {
                return nil
        }

        if (fromVCIndex == 0) || (toVCIndex == 0)  {
            hide = true
        } else {
            hide = false
        }

        currentAnimatedTransitioningType.fromLeft = fromVCIndex > toVCIndex
        return currentAnimatedTransitioningType

    }

    public func tabBarController(_ tabBarController: UITabBarController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return swipeInteractor.interactionInProgress ? swipeInteractor : nil
    }

    open func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        currentAnimatedTransitioningType = swipeAnimatedTransitioning
    }

    public func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        currentAnimatedTransitioningType = tapAnimatedTransitioning
        return true
    }
}

extension SwipeableTabBarController { //: SwipeInteractorDelegate {

    @available(iOS 11.0, *)
    func didStart() {
        if hide {
            setTabBar(hidden: true)
        }
    }

    @available(iOS 11.0, *)
    func didFinish() {
        if isTabBarHidden {
            setTabBar(hidden: false)
        }
    }

// MARK: - Show or hide the tab bar.

    /**
     Show or hide the tab bar.
     - Parameter hidden: `true` if the bar should be hidden.
     - Parameter animated: `true` if the action should be animated.
     - Parameter transitionCoordinator: An optional `UIViewControllerTransitionCoordinator` to perform the animation
     along side with. For example during a push on a `UINavigationController`.
     */
    @available(iOS 11.0, *)
    @objc open func setTabBar(
        hidden: Bool,
        animated: Bool = true,
        along transitionCoordinator: UIViewControllerTransitionCoordinator? = nil
        ) {
        guard isTabBarHidden != hidden else { return }

        let offsetY = hidden ? tabBar.frame.height : -tabBar.frame.height
        let endFrame = tabBar.frame.offsetBy(dx: 0, dy: offsetY)
        let vc: UIViewController? = viewControllers?[selectedIndex]
        var newInsets: UIEdgeInsets? = vc?.additionalSafeAreaInsets
        let originalInsets = newInsets
        newInsets?.bottom -= offsetY

        /// Helper method for updating child view controller's safe area insets.
//        func set(childViewController cvc: UIViewController?, additionalSafeArea: UIEdgeInsets) {
//            cvc?.additionalSafeAreaInsets = additionalSafeArea
//            cvc?.view.setNeedsLayout()
//        }

        // Update safe area insets for the current view controller before the animation takes place when hiding the bar.
//        if hidden, let insets = newInsets { set(childViewController: vc, additionalSafeArea: insets) }

        guard animated else {
            tabBar.frame = endFrame
            return
        }

        // Perform animation with coordinato if one is given. Update safe area insets _after_ the animation is complete,
        // if we're showing the tab bar.
        weak var tabBarRef = self.tabBar
        if let tc = transitionCoordinator {
            tc.animateAlongsideTransition(in: self.view, animation: { _ in tabBarRef?.frame = endFrame }) { context in
                if !hidden, let insets = context.isCancelled ? originalInsets : newInsets {
//                    set(childViewController: vc, additionalSafeArea: insets)
                }
            }
        } else {
            UIView.animate(withDuration: 0.3, animations: { tabBarRef?.frame = endFrame }) { didFinish in
                if !hidden, didFinish, let insets = newInsets {
//                    set(childViewController: vc, additionalSafeArea: insets)
                }
            }
        }
    }

    /// `true` if the tab bar is currently hidden.
    var isTabBarHidden: Bool {
        return !tabBar.frame.intersects(view.frame)
    }

}
