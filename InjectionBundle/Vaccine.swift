#if os(macOS)
import Cocoa
typealias View = NSView
typealias ViewController = NSViewController
typealias ScrollView = NSScrollView
#else
import UIKit
typealias View = UIView
typealias ViewController = UIViewController
typealias ScrollView = UIScrollView

fileprivate extension ViewController {
    func viewWillAppear() { self.viewWillAppear(false) }
    func viewDidAppear() { self.viewDidAppear(false) }
}
#endif

extension View {
    func subviewsRecursive() -> [View] {
        return subviews + subviews.flatMap { $0.subviewsRecursive() }
    }
}

class Vaccine {
    func performInjection(on object: AnyObject) {
        switch object {
        case let viewController as ViewController:
            CATransaction.begin()
            CATransaction.setAnimationDuration(1.0)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))

            defer { CATransaction.commit() }

            let snapshotView = createSnapshot(from: viewController.view)
            if let snapshotView = snapshotView {
                #if os(macOS)
                viewController.view.window?.contentView?.addSubview(snapshotView)
                #else
                let maskView = UIView()
                maskView.frame.size = snapshotView.frame.size
                maskView.frame.origin.y = viewController.navigationController?.navigationBar.frame.maxY ?? 0
                maskView.backgroundColor = .white
                snapshotView.mask = maskView
                viewController.view.window?.addSubview(snapshotView)
                #endif
            }

            let oldScrollViews = indexScrollViews(on: viewController)

            reload(viewController.parent ?? viewController)

            syncOldScrollViews(oldScrollViews, with: indexScrollViews(on: viewController))

            if let snapshotView = snapshotView {
                #if os(macOS)
                NSAnimationContext.runAnimationGroup({ (context) in
                    context.allowsImplicitAnimation = true
                    context.duration = 0.25
                    snapshotView.animator().alphaValue = 0.0
                }, completionHandler: {
                    snapshotView.removeFromSuperview()
                })
                #else
                UIView.animate(withDuration: 1.0,
                               delay: 0.0,
                               options: [.allowAnimatedContent,
                                         .beginFromCurrentState,
                                         .layoutSubviews],
                               animations: {
                                snapshotView.alpha = 0.5
                }) { _ in
                    snapshotView.removeFromSuperview()
                }
                #endif
            }
        case let view as View:
            reload(view)
        default:
            break
        }
    }

    private func reload(_ viewController: ViewController) {
        viewController.view.subviews.forEach { $0.removeFromSuperview() }
        clean(view: viewController.view)
        viewController.loadView()
        viewController.viewDidLoad()
        viewController.viewWillAppear()
        viewController.viewDidAppear()
        refreshSubviews(on: viewController.view)
    }

    private func reload(_ view: View) {
        let selector = _Selector("loadView")
        guard view.responds(to: selector) == true else { return }

        #if os(macOS)
        view.animator().perform(selector)
        #else
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.allowAnimatedContent,
                                                                .beginFromCurrentState,
                                                                .layoutSubviews], animations: {
                                                                    view.perform(selector)
        }, completion: nil)
        #endif
    }

    private func clean(view: View) {
        view.subviews.forEach { $0.removeFromSuperview() }

        #if os(macOS)
        if let sublayers = view.layer?.sublayers {
            sublayers.forEach { $0.removeFromSuperlayer() }
        }
        #else
        if let sublayers = view.layer.sublayers {
            sublayers.forEach { $0.removeFromSuperlayer() }
        }
        #endif
    }

    private func refreshSubviews(on view: View) {
        #if os(macOS)
        view.subviewsRecursive().forEach { view in
            (view as? NSTableView)?.reloadData()
            (view as? NSCollectionView)?.reloadData()
            view.needsLayout = true
            view.layout()
            view.needsDisplay = true
            view.display()
        }
        #else
        view.subviewsRecursive().forEach { view in
            (view as? UITableView)?.reloadData()
            (view as? UICollectionView)?.reloadData()
            view.setNeedsLayout()
            view.layoutIfNeeded()
            view.setNeedsDisplay()
        }
        #endif
    }

    private func indexScrollViews(on viewController: ViewController) -> [ScrollView] {
        var scrollViews = [ScrollView]()

        for case let scrollView as ScrollView in viewController.view.subviews {
            scrollViews.append(scrollView)
        }

        if let parentViewController = viewController.parent {
            for case let scrollView as ScrollView in parentViewController.view.subviews {
                scrollViews.append(scrollView)
            }
        }

        for childViewController in viewController.childViewControllers {
            for case let scrollView as ScrollView in childViewController.view.subviews {
                scrollViews.append(scrollView)
            }
        }

        return scrollViews
    }

    private func syncOldScrollViews(_ oldScrollViews: [ScrollView], with newScrollViews: [ScrollView]) {
        for (offset, scrollView) in newScrollViews.enumerated() {
            if offset < oldScrollViews.count {
                let oldScrollView = oldScrollViews[offset]
                if type(of: scrollView) == type(of: oldScrollView) {
                    #if os(macOS)
                    scrollView.contentView.scroll(to: oldScrollView.documentVisibleRect.origin)
                    #else
                    scrollView.contentOffset = oldScrollView.contentOffset
                    #endif
                }
            }
        }
    }

    private func createSnapshot(from view: View) -> View? {
        #if os(macOS)
        let snapshot = NSImageView()
        snapshot.image = view.snapshot
        snapshot.frame.size = view.frame.size
        return snapshot
        #else
        return view.snapshotView(afterScreenUpdates: false)
        #endif
    }

    private func _Selector(_ string: String) -> Selector {
        return Selector(string)
    }
}

#if os(macOS)
fileprivate extension NSView {
    var snapshot: NSImage {
        guard let bitmapRep = bitmapImageRepForCachingDisplay(in: bounds) else { return NSImage() }
        cacheDisplay(in: bounds, to: bitmapRep)
        let image = NSImage()
        image.addRepresentation(bitmapRep)
        bitmapRep.size = bounds.size.doubleScale()
        return image
    }
}
fileprivate extension CGSize {
    func doubleScale() -> CGSize {
        return CGSize(width: width * 2, height: height * 2)
    }
}
#endif
