//
//  UIViewControllerSwiftInjection.swift
//  InjectionBundle
//
//  Created by Francisco Javier Trujillo Mata on 23/04/2019.
//  Copyright © 2019 John Holdsworth. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit

public extension UIViewController {
    
    /// inject a UIView controller and redraw
    public func injectVC() {
        inject()
        for subview in self.view.subviews {
            subview.removeFromSuperview()
        }
        if let sublayers = self.view.layer.sublayers {
            for sublayer in sublayers {
                sublayer.removeFromSuperlayer()
            }
        }
        viewDidLoad()
    }
    
    @objc(flashToUpdate)
    public func flashToUpdate() {
        DispatchQueue.main.async {
            let v = UIView(frame: self.view.frame)
            v.backgroundColor = .white
            v.alpha = 0.3
            self.view.addSubview(v)
            UIView.animate(withDuration: 0.2,
                           delay: 0.0,
                           options: UIViewAnimationOptions.curveEaseIn,
                           animations: {
                            v.alpha = 0.0
            }, completion: { _ in v.removeFromSuperview() })
        }
    }
}

#else
import Cocoa
#endif
