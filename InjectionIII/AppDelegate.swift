//
//  AppDelegate.swift
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionIII/AppDelegate.swift#94 $
//

import Cocoa

let XcodeBundleID = "com.apple.dt.Xcode"
var appDelegate: AppDelegate!

@NSApplicationMain
class AppDelegate : NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    @IBOutlet weak var enableWatcher: NSMenuItem!
    @IBOutlet weak var traceItem: NSMenuItem!
    @IBOutlet weak var traceInclude: NSTextField!
    @IBOutlet weak var traceExclude: NSTextField!
    @IBOutlet weak var traceFilters: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var startItem: NSMenuItem!
    @IBOutlet weak var xprobeItem: NSMenuItem!
    @IBOutlet weak var enabledTDDItem: NSMenuItem!
    @IBOutlet weak var enableVaccineItem: NSMenuItem!
    @IBOutlet weak var windowItem: NSMenuItem!
    @IBOutlet weak var remoteItem: NSMenuItem!
    @IBOutlet weak var updateItem: NSMenuItem!
    @IBOutlet weak var frontItem: NSMenuItem!
    @IBOutlet var statusItem: NSStatusItem!

    var watchedDirectories = Set<String>()
    weak var lastConnection: InjectionServer?
    var selectedProject: String?
    let openProject = NSLocalizedString("Select Project Directory",
                                        tableName: "Project Directory",
                                        comment: "Project Directory")

    let defaults = UserDefaults.standard
    var defaultsMap: [NSMenuItem: String]!
    lazy var isSandboxed =
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    var runningXcodeDevURL: URL? =
        NSRunningApplication.runningApplications(
            withBundleIdentifier: XcodeBundleID).first?
            .bundleURL?.appendingPathComponent("Contents/Developer")

    @objc func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        appDelegate = self

        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: statusBar.thickness)
        statusItem.toolTip = "Code Injection"
        statusItem.highlightMode = true
        statusItem.menu = statusMenu
        statusItem.isEnabled = true
        statusItem.title = ""

        InjectionServer.startServer(INJECTION_ADDRESS)

        if !FileManager.default.fileExists(atPath:
            "/Applications/Xcode.app/Contents/Developer") {
            let alert: NSAlert = NSAlert()
            alert.messageText = "Missing Xcode at required location"
            alert.informativeText = """
                Xcode.app not found at path /Applications/Xcode.app. \
                You need to have an Xcode at this location to be able \
                to use InjectionIII. A symbolic link at that path is fine.
                """
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            _ = alert.runModal()
        }

        defaultsMap = [
            frontItem: UserDefaultsOrderFront,
            enabledTDDItem: UserDefaultsTDDEnabled,
            enableVaccineItem: UserDefaultsVaccineEnabled
        ]

        for (menuItem, defaultsKey) in defaultsMap {
            menuItem.state = defaults.bool(forKey: defaultsKey) ? .on : .off
        }

        setMenuIcon("InjectionIdle")
        DDHotKeyCenter.shared()?
            .registerHotKey(withKeyCode: UInt16(kVK_ANSI_Equal),
               modifierFlags: NSEvent.ModifierFlags.control.rawValue,
               target:self, action:#selector(autoInject(_:)), object:nil)

        NSApp.servicesProvider = self
        if let lastWatched = defaults.string(forKey: UserDefaultsLastWatched) {
            _ = self.application(NSApp, openFile: lastWatched)
        } else {
            NSUpdateDynamicServices()
        }

        let nextUpdateCheck = defaults.double(forKey: UserDefaultsUpdateCheck)
        if  nextUpdateCheck != 0.0 {
            updateItem.state = .on
            if Date.timeIntervalSinceReferenceDate > nextUpdateCheck {
                self.updateCheck(nil)
            }
        }
    }

    func application(_ theApplication: NSApplication, openFile filename: String) -> Bool {
        let url: URL
        if let resolved = resolve(path: filename) {
            url = resolved
        } else {
            let open = NSOpenPanel()
            open.prompt = openProject
            if filename != "" {
                open.directoryURL = URL(fileURLWithPath: filename)
            }
            open.canChooseDirectories = true
            open.canChooseFiles = false
            // open.showsHiddenFiles = TRUE;
            if open.runModal() == .OK {
                url = open.url!
                persist(url: url)
            } else {
                return false
            }
        }

        if let fileList = try? FileManager.default
            .contentsOfDirectory(atPath: url.path),
            let projectFile =
                fileWithExtension("xcworkspace", inFiles: fileList) ??
                fileWithExtension("xcodeproj", inFiles: fileList) {
            selectedProject = url
                .appendingPathComponent(projectFile).path
            watchedDirectories.removeAll()
            watchedDirectories.insert(url.path)
            lastConnection?.setProject(self.selectedProject!)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
//            let projectName = URL(fileURLWithPath: projectFile)
//                .deletingPathExtension().lastPathComponent
//            traceInclude.stringValue = projectName
//            updateTraceInclude(nil)
            defaults.set(url.path, forKey: UserDefaultsLastWatched)
            return true
        }

        let alert: NSAlert = NSAlert()
        alert.messageText = "Injection"
        alert.informativeText = "Please select a directory with either a .xcworkspace or .xcodeproj file, below which, are the files you wish to inject."
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "OK")
        _ = alert.runModal()

        return false
    }

    func fileWithExtension(_ ext: String, inFiles files: [String]) -> String? {
        return files.first { ($0 as NSString).pathExtension == ext }
    }

    func persist(url: URL) {
        var bookmarks = defaults.value(forKey: UserDefaultsBookmarks)
            as? [String : Data] ?? [String: Data]()
        do {
            bookmarks[url.path] =
                try url.bookmarkData(options: [.withSecurityScope,
                                               .securityScopeAllowOnlyReadAccess],
                                     includingResourceValuesForKeys: [],
                                     relativeTo: nil)
            defaults.set(bookmarks, forKey: UserDefaultsBookmarks)
        } catch {
            _ = InjectionServer.error("Bookmarking failed for \(url), \(error)")
        }
    }

    func resolve(path: String) -> URL? {
        var isStale: Bool = false
        if let bookmarks =
            defaults.value(forKey: UserDefaultsBookmarks) as? [String : Data],
            let bookmark = bookmarks[path],
            let resolved = try? URL(resolvingBookmarkData: bookmark,
                           options: .withSecurityScope,
                           relativeTo: nil,
                           bookmarkDataIsStale: &isStale), !isStale {
            _ = resolved.startAccessingSecurityScopedResource()
            return resolved
        }

        return nil
    }

    func setMenuIcon(_ tiffName: String) {
        DispatchQueue.main.async {
            if let path = Bundle.main.path(forResource: tiffName, ofType: "tif"),
                let image = NSImage(contentsOfFile: path) {
    //            image.template = TRUE;
                self.statusItem.image = image
                self.statusItem.alternateImage = self.statusItem.image
                let appRunning = tiffName != "InjectionIdle"
                self.startItem.isEnabled = appRunning
                self.xprobeItem.isEnabled = appRunning
                for item in self.traceItem.submenu!.items {
                    if item.title != "Set Filters" {
                        item.isEnabled = appRunning
                        if !appRunning {
                            item.state = .off
                        }
                    }
                }
            }
        }
    }

    @IBAction func openProject(_ sender: Any) {
        _ = application(NSApp, openFile: "")
    }

    @IBAction func addDirectory(_ sender: Any) {
        let open = NSOpenPanel()
        open.prompt = openProject
        open.allowsMultipleSelection = true
        open.canChooseDirectories = true
        open.canChooseFiles = false
        if open.runModal() == .OK {
            for url in open.urls {
                appDelegate.watchedDirectories.insert(url.path)
                self.lastConnection?.watchDirectory(url.path)
                persist(url: url)
            }
        }
    }

    func setFrameworks(_ frameworks: String, menuTitle: String) {
        DispatchQueue.main.async {
            guard let frameworksMenu = self.traceItem.submenu?
                    .item(withTitle: menuTitle)?.submenu else { return }
            frameworksMenu.removeAllItems()
            for framework in frameworks
                .components(separatedBy: FRAMEWORK_DELIMITER).sorted()
                where framework != "" {
                frameworksMenu.addItem(withTitle: framework, action:
                    #selector(self.traceFramework(_:)), keyEquivalent: "")
                    .target = self
            }
        }
    }

    @objc func traceFramework(_ sender: NSMenuItem) {
        toggleState(sender)
        lastConnection?.sendCommand(.traceFramework, with: sender.title)
    }

    @IBAction func toggleTDD(_ sender: NSMenuItem) {
        toggleState(sender)
    }

    @IBAction func toggleVaccine(_ sender: NSMenuItem) {
        toggleState(sender)
        lastConnection?.sendCommand(.vaccineSettingChanged, with:vaccineConfiguration())
    }

    @IBAction func startRemote(_ sender: NSMenuItem) {
        RMWindowController.startServer(sender)
        remoteItem.state = .on
    }

    @IBAction func stopRemote(_ sender: NSMenuItem) {
        RMWindowController.stopServer()
        remoteItem.state = .off
    }

    @IBAction func traceApp(_ sender: NSMenuItem) {
        toggleState(sender)
        lastConnection?.sendCommand(sender.state == .on ?
            .trace : .untrace, with: nil)
    }

    @IBAction func traceUIApp(_ sender: NSMenuItem) {
        toggleState(sender)
        lastConnection?.sendCommand(.traceUI, with: nil)
    }

    @IBAction func traceUIKit(_ sender: NSMenuItem) {
        toggleState(sender)
        lastConnection?.sendCommand(.traceUIKit, with: nil)
    }

    @IBAction func traceSwiftUI(_ sender: NSMenuItem) {
        toggleState(sender)
        lastConnection?.sendCommand(.traceSwiftUI, with: nil)
    }

    @IBAction func traceStats(_ sender: NSMenuItem) {
        lastConnection?.sendCommand(.stats, with: nil)
    }

    @IBAction func remmoveTraces(_ sender: NSMenuItem?) {
        lastConnection?.sendCommand(.uninterpose, with: nil)
    }

    @IBAction func showTraceFilters(_ sender: NSMenuItem?) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        traceFilters.makeKeyAndOrderFront(sender)
    }

    @IBAction func updateTraceInclude(_ sender: NSButton?) {
        update(filter: sender == nil ? .quietInclude : .include,
               textField: traceInclude)
    }

    @IBAction func updateTraceExclude(_ sender: NSButton?) {
        update(filter: .exclude, textField: traceExclude)
    }

    func update(filter: InjectionCommand, textField: NSTextField) {
        let regex = textField.stringValue
        do {
            if regex != "" {
                _ = try NSRegularExpression(pattern: regex, options: [])
            }
            lastConnection?.sendCommand(filter, with: regex)
        } catch {
            let alert = NSAlert(error: error)
            alert.informativeText = "Invalid regular expression syntax '\(regex)' for filter. Characters [](){}|?*+\\ and . have special meanings. Type: man re_syntax, in the terminal."
            alert.runModal()
            textField.becomeFirstResponder()
            showTraceFilters(nil)
        }
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
        if let defaultsKey = defaultsMap[sender] {
            defaults.set(sender.state, forKey: defaultsKey)
        }
    }

    @IBAction func autoInject(_ sender: NSMenuItem) {
        lastConnection?.injectPending()
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

    @IBAction func help(_ sender: Any) {
        _ = NSWorkspace.shared.open(URL(string:
            "https://github.com/johnno1962/InjectionIII")!)
    }

    @IBAction func sponsor(_ sender: Any) {
        _ = NSWorkspace.shared.open(URL(string:
            "https://github.com/sponsors/johnno1962")!)
    }

    @objc
    public func applicationWillTerminate(aNotification: NSNotification) {
            // Insert code here to tear down your application
        DDHotKeyCenter.shared()
            .unregisterHotKey(withKeyCode: UInt16(kVK_ANSI_Equal),
             modifierFlags: NSEvent.ModifierFlags.control.rawValue)
    }
}
