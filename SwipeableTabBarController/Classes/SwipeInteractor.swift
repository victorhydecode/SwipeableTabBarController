//
//  MGSwipeInteractor.swift
//  MGSwipeableTabBarController
//
//  Created by Marcos Griselli on 1/26/17.
//  Copyright © 2017 Marcos Griselli. All rights reserved.
//

import UIKit

protocol SwipeInteractorDelegate {
    func panGestureDidStart()
    func panGestureDidFinish()
}

/// Responsible of adding the `UIPanGestureRecognizer` to the current
/// tab selected on the `UITabBarController` subclass.
class SwipeInteractor: UIPercentDrivenInteractiveTransition {

    // MARK: - Private
    private var viewController: UIViewController!
    private var rightToLeftSwipe = false
    private var shouldCompleteTransition = false
    private var canceled = false

    // MARK: - Fileprivate
    fileprivate var lPanRecognizer: UIScreenEdgePanGestureRecognizer?
    fileprivate var rPanRecognizer: UIScreenEdgePanGestureRecognizer?

    fileprivate struct InteractionConstants {
        static let yTranslationForSuspend: CGFloat = 5.0
        static let yVelocityForSuspend: CGFloat = 100.0
        static let xVelocityForComplete: CGFloat = 200.0
        static let xTranslationForRecognition: CGFloat = 5.0
    }

    fileprivate struct AssociatedKey {
        static var swipeGestureKeyLeft = "kSwipeableTabBarControllerGestureKeyLeft"
        static var swipeGestureKeyRight = "kSwipeableTabBarControllerGestureKeyRight"
    }

    // MARK: - Public
    var isDiagonalSwipeEnabled = false
    var interactionInProgress = false

    typealias Closure = (() -> ())
    var onfinishTransition: Closure?

    var delegate: SwipeInteractorDelegate?

    /// Sets the viewController to be the one in charge of handling the swipe transition.
    ///
    /// - Parameter viewController: `UIViewController` in charge of the the transition.
    public func wireTo(viewController: UIViewController) {
        self.viewController = viewController
        prepareGestureRecognizer(inView: viewController.view)
    }


    /// Adds the `UIPanGestureRecognizer` to the controller's view to handle swiping.
    ///
    /// - Parameter view: `UITabBarController` tab controller's view (`UINavigationControllers` not included).
    public func prepareGestureRecognizer(inView view: UIView) {
        lPanRecognizer = objc_getAssociatedObject(view, &AssociatedKey.swipeGestureKeyLeft) as? UIScreenEdgePanGestureRecognizer
        rPanRecognizer = objc_getAssociatedObject(view, &AssociatedKey.swipeGestureKeyRight) as? UIScreenEdgePanGestureRecognizer

        if let swipe = lPanRecognizer {
            view.removeGestureRecognizer(swipe)
        }
        if let swipe = rPanRecognizer {
            view.removeGestureRecognizer(swipe)
        }

        lPanRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(SwipeInteractor.handlePan(_:)))
        lPanRecognizer?.edges = .left
        lPanRecognizer?.delegate = self
        lPanRecognizer?.isEnabled = isEnabled
        view.addGestureRecognizer(lPanRecognizer!)

        rPanRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(SwipeInteractor.handlePan(_:)))
        rPanRecognizer?.edges = .right
        rPanRecognizer?.delegate = self
        rPanRecognizer?.isEnabled = isEnabled
        view.addGestureRecognizer(rPanRecognizer!)

        objc_setAssociatedObject(view, &AssociatedKey.swipeGestureKeyLeft, lPanRecognizer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &AssociatedKey.swipeGestureKeyRight, rPanRecognizer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }


    /// Handles the swiping with progress
    ///
    /// - Parameter recognizer: `UIPanGestureRecognizer` in the current tab controller's view.
    @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {

        let translation = recognizer.translation(in: recognizer.view?.superview)
        let velocity = recognizer.velocity(in: recognizer.view)

        switch recognizer.state {
        case .began:
            delegate?.panGestureDidStart()

            if shouldSuspendInteraction(yTranslation: translation.y, yVelocity: velocity.y) {
                interactionInProgress = false
                return
            }

            rightToLeftSwipe = velocity.x < 0

            if rightToLeftSwipe && viewController.tabBarController!.selectedIndex != 0 {
                interactionInProgress = false
                return
            }

            if !rightToLeftSwipe && viewController.tabBarController!.selectedIndex != 1 {
                interactionInProgress = false
                return
            }

            if rightToLeftSwipe {
                if viewController.tabBarController!.selectedIndex < viewController.tabBarController!.viewControllers!.count - 1 {
                    interactionInProgress = true
                    viewController.tabBarController?.selectedIndex += 1
                }
            } else {
                if viewController.tabBarController!.selectedIndex > 0 {
                    interactionInProgress = true
                    viewController.tabBarController?.selectedIndex -= 1
                }
            }
            //            if interactionInProgress, #available(iOS 11.0, *) {
            //                delegate?.didStart()
        //            }
        case .changed:
            if interactionInProgress {
                let translationValue = translation.x/UIScreen.main.bounds.size.width

                // TODO (marcosgriselli): support dual side swipping in one drag.
                if rightToLeftSwipe && translationValue > 0 {
                    self.update(0)
                    return
                } else if !rightToLeftSwipe && translationValue < 0 {
                    self.update(0)
                    return
                }

                var fraction = fabs(translationValue)
                fraction = min(max(fraction, 0.0), 0.99)
                shouldCompleteTransition = (fraction > 0.5);

                self.update(fraction)
            }

        case .ended, .cancelled:
            if interactionInProgress {
                interactionInProgress = false
                delegate?.panGestureDidFinish()

                //                if #available(iOS 11.0, *) {
                //                    delegate?.didFinish()
                //                }

                if !shouldCompleteTransition {
                    if (rightToLeftSwipe && velocity.x < -InteractionConstants.xVelocityForComplete) {
                        shouldCompleteTransition = true
                    } else if (!rightToLeftSwipe && velocity.x > InteractionConstants.xVelocityForComplete) {
                        shouldCompleteTransition = true
                    }
                }

                if !shouldCompleteTransition || recognizer.state == .cancelled {
                    cancel()
                } else {
                    // Avoid launching a new transaction while the previous one is finishing.
                    //recognizer.isEnabled = false
                    finish()
                    onfinishTransition?()
                }
            }

        default : break
        }
    }

    /// enables/disables the entire interactor.
    public var isEnabled = true {
        didSet {
            lPanRecognizer?.isEnabled = isEnabled
            rPanRecognizer?.isEnabled = isEnabled
        }
    }

    /// Checks for the diagonal swipe support. It evaluates if the current gesture is diagonal or Y-Axis based.
    ///
    /// - Parameters:
    ///   - yTranslation: gesture translation on the Y-axis.
    ///   - yVelocity: gesture velocity on the Y-axis.
    /// - Returns: boolean determing wether the interaction should take place or not.
    private func shouldSuspendInteraction(yTranslation: CGFloat, yVelocity: CGFloat) -> Bool {
        if !isDiagonalSwipeEnabled {
            // Cancel interaction if the movement is on the Y axis.
            let isTranslatingOnYAxis = fabs(yTranslation) > InteractionConstants.yTranslationForSuspend
            let hasVelocityOnYAxis = fabs(yVelocity) > InteractionConstants.yVelocityForSuspend

            return isTranslatingOnYAxis || hasVelocityOnYAxis
        }
        return false
    }
}

// MARK: - UIGestureRecognizerDelegate
extension SwipeInteractor: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == lPanRecognizer {
            if let point = lPanRecognizer?.translation(in: lPanRecognizer?.view?.superview) {
                return fabs(point.x) < InteractionConstants.xTranslationForRecognition
            }
        }
        if gestureRecognizer == rPanRecognizer {
            if let point = rPanRecognizer?.translation(in: rPanRecognizer?.view?.superview) {
                return fabs(point.x) < InteractionConstants.xTranslationForRecognition
            }
        }
        return true
    }
}
