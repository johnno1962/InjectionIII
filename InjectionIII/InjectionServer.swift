//
//  InjectionServer.swift
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

let XcodeBundleID = "com.apple.dt.Xcode"
let injectionQueue = DispatchQueue(label: "InjectionQueue")

var projectInjected = ["": ["": Date.timeIntervalSinceReferenceDate]]
let MIN_INJECTION_INTERVAL = 1.0

public class InjectionServer: SimpleSocket {
    var injector: ((_ changed: NSArray) -> Void)? = nil
    var fileWatchers = [FileWatcher]()
    var pending = [String]()

    @objc(error:)
    override public class func error(_ message: String) -> Int32 {
        let saveno = errno
        DispatchQueue.main.sync {
            let alert: NSAlert = NSAlert()
            alert.messageText = "Injection Error"
            alert.informativeText = String(format:message, strerror(saveno))
            alert.alertStyle = NSAlert.Style.warning
            alert.addButton(withTitle: "OK")
            _ = alert.runModal()
        }
        return -1
    }

    func sendCommand(_ command: InjectionCommand, with string: String?) {
        writeCommand(command.rawValue, with: string)
    }

    @objc override public func runInBackground() {
        write(NSHomeDirectory())

        var candiateProjectFile = appDelegate.selectedProject
//        var MAS = false

    //    if (!projectFile) {
    //        XcodeApplication *xcode = (XcodeApplication *)[SBApplication
    //                           applicationWithBundleIdentifier:XcodeBundleID];
    //        XcodeWorkspaceDocument *workspace = [xcode activeWorkspaceDocument];
    //        projectFile = workspace.file.path;
    //    }

        if candiateProjectFile == nil {
            DispatchQueue.main.sync {
                appDelegate.openProject(self)
            }
            candiateProjectFile = appDelegate.selectedProject
//            MAS = true
        }
        guard let projectFile = candiateProjectFile else {
            return
        }

        NSLog("Connection with project file: \(projectFile)")

        // tell client app the inferred project being watched
        let key = readString()
        if key != INJECTION_KEY {
            return
        }

        let builder = SwiftEval()

        // client spcific data for building
        if let frameworks = readString() {
            builder.frameworks = frameworks
        } else { return }

        if let arch = readString() {
            builder.arch = arch
        } else { return }

        // Xcode specific config
        if let xcode = NSRunningApplication
            .runningApplications(withBundleIdentifier: XcodeBundleID).first {
            builder.xcodeDev = xcode.bundleURL!.path + "/Contents/Developer"
        }

        builder.projectFile = projectFile

        let projectName = URL(fileURLWithPath: projectFile)
            .deletingPathExtension().lastPathComponent
        let derivedLogs = String(format: "%@/Library/Developer/Xcode/DerivedData/%@-%@/Logs/Build",
                                 NSHomeDirectory(), projectName
                                    .replacingOccurrences(of: "[\\s]+", with:"_",
                                   options:.regularExpression),
//            NSRegularExpressionSearch range:NSMakeRange(0, projectName.length)],
            XcodeHash.hashString(forPath: projectFile))
        if FileManager.default.fileExists(atPath:derivedLogs) {
            builder.derivedLogs = derivedLogs
        }
        else {
            NSLog("Bad estimate of Derived Logs: \(projectFile) -> \(derivedLogs)")
        }

        // callback on errors
        builder.evalError = {
            (message: String) in
            self.sendCommand(.log, with:message)
            return NSError(domain:"SwiftEval", code:-1,
                                          userInfo:[NSLocalizedDescriptionKey: message])
        }

        appDelegate.setMenuIcon("InjectionOK")
        appDelegate.lastConnection = self
        pending = []

        let inject = {
            (swiftSource: String) in
            let watcherState = appDelegate.enableWatcher.state
            injectionQueue.async {
                if watcherState == NSControl.StateValue.on {
                    appDelegate.setMenuIcon("InjectionBusy")
    //                if (!MAS) {
    //                    if (NSString *tmpfile = [builder rebuildClassWithOldClass:nil
    //                                                              classNameOrFile:swiftSource extra:nil error:nil])
    //                        [self writeString:[@"LOAD " stringByAppendingString:tmpfile]];
    //                    else
    //                        [appDelegate setMenuIcon:@"InjectionError"];
    //                }
    //                else
                    self.sendCommand(.inject, with:swiftSource)
                }
                else {
                    self.sendCommand(.log, with:"The file watcher is turned off")
                }
            }
        }

        var lastInjected = projectInjected[projectFile]
        if lastInjected == nil {
            lastInjected = [String: Double]()
            projectInjected[projectFile] = lastInjected!
        }

        if let executable = readString() {
            let mtime = {
                (path: String) -> time_t in
                var info = stat()
                return stat(path, &info) == 0 ? info.st_mtimespec.tv_sec : 0
            }
            let executableBuild = mtime(executable)
            for (source, _) in lastInjected! {
                if !source.hasSuffix("storyboard") && !source.hasSuffix("xib") &&
                    mtime(source) > executableBuild {
                    inject(source)
                }
            }
        }
        else { return }

        var pause: TimeInterval = 0.0

        // start up a file watcher to write generated tmpfile path to client app

        var testCache = [String: [String]]()

        injector = {
            (changed: NSArray) in
            var changed = changed as! [String]

            if UserDefaults.standard.bool(forKey: UserDefaultsTDDEnabled) {
                for injectedFile in changed {
                    var matchedTests = testCache[injectedFile]
                    if matchedTests == nil {
                        matchedTests = Self.searchForTestWithFile(injectedFile,
                              projectRoot:(projectFile as NSString)
                                .deletingLastPathComponent,
                            fileManager: FileManager.default)
                        testCache[injectedFile] = matchedTests
                    }

                    changed += matchedTests!
                }
            }

            let now = NSDate.timeIntervalSinceReferenceDate
            let automatic = appDelegate.enableWatcher.state == NSControl.StateValue.on
            for swiftSource in changed {
                if !self.pending.contains(swiftSource) {
                    if (now > (lastInjected?[swiftSource] ?? 0.0) + MIN_INJECTION_INTERVAL && now > pause) {
                        lastInjected![swiftSource] = now
                        projectInjected[projectFile] = lastInjected!
                        self.pending.append(swiftSource)
                        if !automatic {
                            self.sendCommand(.log,
                                        with:"'\((swiftSource as NSString).lastPathComponent), type ctrl-= to inject")
                        }
                    }
                }
            }

            if (automatic) {
                self.injectPending()
            }
        };

        setProject(projectFile)

        // read status requests from client app
        commandLoop:
        while true {
            let commandInt = readInt()
            guard let command = InjectionResponse(rawValue: commandInt) else {
                NSLog("InjectionServer: Unexpected case \(commandInt)")
                break
            }
            switch command {
            case .complete:
                appDelegate.setMenuIcon("InjectionOK")
                break
            case .pause:
                pause = NSDate.timeIntervalSinceReferenceDate + Double(readString() ?? "0.0")!
                break
            case .sign:
                let signedOK = SignerService.codesignDylib(readString()!)
                sendCommand(.signed, with: signedOK ? "1": "0")
                break
            case .error:
                appDelegate.setMenuIcon("InjectionError")
                NSLog("Injection error: \(readString() ?? "Uknown")")
    //            dispatch_async(dispatch_get_main_queue(), ^{
    //                [[NSAlert alertWithMessageText:@"Injection Error"
    //                                 defaultButton:@"OK" alternateButton:nil otherButton:nil
    //                     informativeTextWithFormat:@"%@",
    //                  [dylib substringFromIndex:@"ERROR ".length]] runModal];
    //            });
                break;
            case .exit:
                break commandLoop
            default:
                break
            }
        }

        // client app disconnected
        injector = nil
        fileWatchers.removeAll()
        appDelegate.setMenuIcon("InjectionIdle")
        appDelegate.traceItem.state = NSControl.StateValue.off
    }

    @objc (watchDirectory:)
    public func watchDirectory(_ directory: String) {
        fileWatchers.append(FileWatcher(root:directory,
                                        callback:injector!))
        sendCommand(.watching, with:directory)
    }

    @objc public func injectPending() {
        for swiftSource in pending {
            injectionQueue.async {
                self.sendCommand(.inject, with:swiftSource)
            }
        }
        pending.removeAll()
    }

    @objc public func setProject(_ project: String) {
        guard injector != nil else { return }
        sendCommand(.vaccineSettingChanged,
                    with:appDelegate.vaccineConfiguration())
        fileWatchers.removeAll()
        sendCommand(.connected, with:project)
        for directory in appDelegate.watchedDirectories {
            watchDirectory(directory)
        }
    }

    class func searchForTestWithFile(_ injectedFile: String,
            projectRoot: String, fileManager: FileManager) -> [String] {
        var matchedTests = [String]()
        let injectedFileName = URL(fileURLWithPath: injectedFile)
            .deletingPathExtension().path
        let projectUrl = URL(string: urlEncode(string: projectRoot))!
        if let enumerator = fileManager.enumerator(at: projectUrl,
                includingPropertiesForKeys: [URLResourceKey.nameKey,
                                             URLResourceKey.isDirectoryKey],
                options: .skipsHiddenFiles,
                errorHandler: {
                    (url: URL, error: Error) -> Bool in
                    if error !=  nil {
                        NSLog("[Error] \(error) (\(url))")
                         return false
                     }
                     return true
        }) {
            for fileURL in enumerator {
                var filename: AnyObject?
                var isDirectory: AnyObject?
                if let fileURL = fileURL as? NSURL {
                    try! fileURL.getResourceValue(&filename, forKey:URLResourceKey.nameKey)
                    try! fileURL.getResourceValue(&isDirectory, forKey:URLResourceKey.isDirectoryKey)

                    if filename?.hasPrefix("_") == true &&
                        isDirectory?.boolValue == true {
                        enumerator.skipDescendants()
                        continue
                    }

                    if isDirectory?.boolValue == false &&
                        filename?.lastPathComponent !=
                            (injectedFile as NSString).lastPathComponent &&
                        filename?.lowercased
                            .contains(injectedFileName.lowercased()) == true {
                        matchedTests.append(fileURL.path!)
                    }
                }
            }
    }

        return matchedTests
    }

    public class func urlEncode(string: String) -> String {
        let unreserved = "-._~/?"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: unreserved)
        return string.addingPercentEncoding(withAllowedCharacters: allowed)!
    }

    deinit {
        NSLog("- [\(self) dealloc]")
    }
}
