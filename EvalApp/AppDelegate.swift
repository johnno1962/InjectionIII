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

    @IBAction func performEval(_: Any) {
        textView.string = eval(textField.stringValue)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        evalError = {
            let err = $0
            DispatchQueue.main.async {
                self.textView.string = err
            }
            return nil
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
