// Defense-in-depth: native iOS blur overlay when app resigns active.
// Flutter overlay alone may not paint before iOS snapshot (app-switcher
// preview); this guarantees blur.
//
// Paste into ios/Runner/AppDelegate.swift inside @main AppDelegate.

import UIKit

extension AppDelegate {
    private static var blurViewKey: UInt8 = 0
    private var blurView: UIVisualEffectView? {
        get { objc_getAssociatedObject(self, &Self.blurViewKey) as? UIVisualEffectView }
        set { objc_setAssociatedObject(self, &Self.blurViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    override func applicationWillResignActive(_ application: UIApplication) {
        super.applicationWillResignActive(application)
        addBlurOverlay()
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        removeBlurOverlay()
    }

    private func addBlurOverlay() {
        guard let window = window, blurView == nil else { return }
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        v.frame = window.bounds
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(v)
        blurView = v
    }

    private func removeBlurOverlay() {
        blurView?.removeFromSuperview()
        blurView = nil
    }
}
