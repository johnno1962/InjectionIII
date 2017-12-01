//
//  AppDelegate.swift
//  EvalApp
//
//  Created by John Holdsworth on 04/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var textView: NSTextView!
    @IBOutlet weak var closureText: NSTextField!

    @IBAction func performEval(_: Any) {
        textView.string = eval(textField.stringValue)
    }

    @IBAction func closureEval(_: Any) {
        if let block = eval(closureText.stringValue, (() -> ())?.self) {
            block()
        }
    }

    @objc func injected() {
        print("I've been injected!")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        SwiftEval.instance.evalError = {
            let err = $0
            if !err.hasPrefix("Compiling ") {
                DispatchQueue.main.async {
                    self.textView.string = err
                }
            }
            return NSError(domain: "SwiftEval", code: -1, userInfo: [NSLocalizedDescriptionKey: err])
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
