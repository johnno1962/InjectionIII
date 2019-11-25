//
//  AppDelegate.swift
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionIII/AppDelegate.swift#11 $
//

import Cocoa

var appDelegate: AppDelegate!

@NSApplicationMain
class AppDelegate : NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    @IBOutlet weak var enableWatcher: NSMenuItem!
    @IBOutlet weak var traceItem: NSMenuItem!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var startItem: NSMenuItem!
    @IBOutlet weak var xprobeItem: NSMenuItem!
    @IBOutlet weak var enabledTDDItem: NSMenuItem!
    @IBOutlet weak var enableVaccineItem: NSMenuItem!
    @IBOutlet weak var windowItem: NSMenuItem!
    @IBOutlet weak var frontItem: NSMenuItem!
    @IBOutlet var statusItem: NSStatusItem!

    var watchedDirectories = Set<String>()
    weak var lastConnection: InjectionServer?
    var selectedProject: String?

    @objc func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        appDelegate = self
        InjectionServer.startServer(INJECTION_ADDRESS)

        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: statusBar.thickness)
        statusItem.toolTip = "Code Injection"
        statusItem.highlightMode = true
        statusItem.menu = statusMenu
        statusItem.isEnabled = true
        statusItem.title = ""

        enabledTDDItem.state = UserDefaults.standard.bool(forKey:UserDefaultsTDDEnabled)
            ? .on : .off
        enableVaccineItem.state = UserDefaults.standard.bool(forKey:UserDefaultsVaccineEnabled)
            ? .on : .off

        setMenuIcon("InjectionIdle")
        DDHotKeyCenter.shared()?
            .registerHotKey(withKeyCode: UInt16(kVK_ANSI_Equal),
               modifierFlags: NSEvent.ModifierFlags.control.rawValue,
               target:self, action:#selector(autoInject(_:)), object:nil)
    }

    func application(_ theApplication: NSApplication, openFile filename: String) -> Bool {
        let open = NSOpenPanel()
        open.prompt = NSLocalizedString("Select Project Directory", tableName: "Project Directory", comment: "Project Directory")
        if filename != "" {
            open.directoryURL = URL(fileURLWithPath: filename)
        }
        open.canChooseDirectories = true
        open.canChooseFiles = false
        // open.showsHiddenFiles = TRUE;
        if open.runModal() == .OK {
            let fileList = try? FileManager.default
                .contentsOfDirectory(atPath: open.url!.path)
            if let fileList = fileList, let projectFile =
               fileWithExtension("xcworkspace", inFiles: fileList) ??
               fileWithExtension("xcodeproj", inFiles: fileList) ??
                fileList.first(where: {$0 == "Package.swift"}),
                let url = open.url {
                self.selectedProject = url
                    .appendingPathComponent(projectFile).path
                self.watchedDirectories.removeAll()
                self.watchedDirectories.insert(url.path)
                self.lastConnection?.setProject(self.selectedProject!)
                NSDocumentController.shared
                    .noteNewRecentDocumentURL(url)
                return true
            }
        }
        return false
    }

    func fileWithExtension(_ ext: String, inFiles files: [String]) -> String? {
        for file in files {
            if (file as NSString).pathExtension == ext {
                return file
            }
        }
        return nil
    }

    func setMenuIcon(_ tiffName: String) {
        DispatchQueue.main.async {
            if let path = Bundle.main.path(forResource: tiffName, ofType:"tif"),
                let image = NSImage(contentsOfFile: path) {
    //            image.template = TRUE;
                self.statusItem.image = image
                self.statusItem.alternateImage = self.statusItem.image
                self.startItem.isEnabled = tiffName == "InjectionIdle"
                self.xprobeItem.isEnabled = !self.startItem.isEnabled
            }
        }
    }

    @IBAction func openProject(_ sender: Any) {
        _ = application(NSApp, openFile:"")
    }

    @IBAction func addDirectory(_ sender: Any) {
        let open = NSOpenPanel()
        open.prompt = NSLocalizedString("Add Project Directory", tableName: "Project Directory", comment: "Project Directory")
        open.allowsMultipleSelection = true
        open.canChooseDirectories = true
        open.canChooseFiles = false
        if open.runModal() == .OK {
            for url in open.urls {
                appDelegate.watchedDirectories.insert(url.path)
                self.lastConnection?.watchDirectory(url.path)
            }
        }
    }

    @IBAction func toggleTDD(_ sender: NSMenuItem) {
        toggleState(sender)
        let newSetting = sender.state == .on
        UserDefaults.standard.set(newSetting, forKey:UserDefaultsTDDEnabled)
    }

    @IBAction func toggleVaccine(_ sender: NSMenuItem) {
        toggleState(sender)
        let newSetting = sender.state == .on
        UserDefaults.standard.set(newSetting, forKey:UserDefaultsVaccineEnabled)
        self.lastConnection?.sendCommand(.vaccineSettingChanged, with:vaccineConfiguration())
    }

    @IBAction func traceApp(_ sender: NSMenuItem) {
        toggleState(sender)
        self.lastConnection?.sendCommand(sender.state == NSControl.StateValue.on ?
            .trace : .untrace, with: nil)
    }

    func vaccineConfiguration() -> String {
        let vaccineSetting = UserDefaults.standard.bool(forKey: UserDefaultsVaccineEnabled)
        let dictionary = [UserDefaultsVaccineEnabled: vaccineSetting]
        let jsonData = try! JSONSerialization
            .data(withJSONObject: dictionary, options:[])
        let configuration = String(data: jsonData, encoding: .utf8)!
        return configuration
    }

    @IBAction func toggleState(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
    }

    @IBAction func autoInject(_ sender: NSMenuItem) {
        self.lastConnection?.injectPending()
//    #if false
//        NSError *error = nil;
//        // Install helper tool
//        if ([HelperInstaller isInstalled] == NO) {
//    #pragma clang diagnostic push
//    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
//            if ([[NSAlert alertWithMessageText:@"Injection Helper"
//                                 defaultButton:@"OK" alternateButton:@"Cancel" otherButton:nil
//                     informativeTextWithFormat:@"InjectionIII needs to install a privileged helper to be able to inject code into "
//                  "an app running in the iOS simulator. This is the standard macOS mechanism.\n"
//                  "You can remove the helper at any time by deleting:\n"
//                  "/Library/PrivilegedHelperTools/com.johnholdsworth.InjectorationIII.Helper.\n"
//                  "If you'd rather not authorize, patch the app instead."] runModal] == NSAlertAlternateReturn)
//                return;
//    #pragma clang diagnostic pop
//            if ([HelperInstaller install:&error] == NO) {
//                NSLog(@"Couldn't install Smuggler Helper (domain: %@ code: %d)", error.domain, (int)error.code);
//                [[NSAlert alertWithError:error] runModal];
//                return;
//            }
//        }
//
//        // Inject Simulator process
//        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"iOSInjection" ofType:@"bundle"];
//        if ([HelperProxy inject:bundlePath error:&error] == FALSE) {
//            NSLog(@"Couldn't inject Simulator (domain: %@ code: %d)", error.domain, (int)error.code);
//            [[NSAlert alertWithError:error] runModal];
//        }
//    #endif
    }

    @IBAction func runXprobe(_ sender: NSMenuItem) {
        if xprobePlugin == nil {
            xprobePlugin = XprobePluginMenuController()
            xprobePlugin.applicationDidFinishLaunching(Notification(name: Notification.Name(rawValue: "")))
            xprobePlugin.injectionPlugin = unsafeBitCast(self, to: AnyClass.self)
        }
        lastConnection?.sendCommand(.xprobe, with:"")
        windowItem.isHidden = false
    }

    @objc func evalCode(_ swift: String) {
        self.lastConnection?.sendCommand(.eval, with:swift)
    }

    @IBAction func donate(_ sender: Any) {
        _ = NSWorkspace.shared.open(URL(string: "http://johnholdsworth.com/cgi-bin/injection3.cgi")!)
    }

    @objc
    public func applicationWillTerminate(aNotification: NSNotification) {
            // Insert code here to tear down your application
        DDHotKeyCenter.shared()
            .unregisterHotKey(withKeyCode: UInt16(kVK_ANSI_Equal),
             modifierFlags: NSEvent.ModifierFlags.control.rawValue)
    }
}
