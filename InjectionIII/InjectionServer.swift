//
//  InjectionServer.swift
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionIII/InjectionServer.swift#47 $
//

let XcodeBundleID = "com.apple.dt.Xcode"
let commandQueue = DispatchQueue(label: "InjectionCommand")

var projectInjected = [String: [String: TimeInterval]]()
let MIN_INJECTION_INTERVAL = 1.0

public class InjectionServer: SimpleSocket {
    var fileChangeHandler: ((_ changed: NSArray, _ ideProcPath:String) -> Void)!
    var fileWatchers = [FileWatcher]()
    var pending = [String]()
    var builder: SwiftEval!
    var lastIdeProcPath = ""

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
        commandQueue.sync {
            _ = writeCommand(command.rawValue, with: string)
        }
    }

    @objc override public func runInBackground() {
        let tmpDir = NSTemporaryDirectory()
        write(tmpDir)

        var candiateProjectFile = appDelegate.selectedProject

        if candiateProjectFile == nil {
            DispatchQueue.main.sync {
                appDelegate.openProject(self)
            }
            candiateProjectFile = appDelegate.selectedProject
        }
        guard let projectFile = candiateProjectFile else {
            return
        }

        NSLog("Connection with project file: \(projectFile)")

        // tell client app the inferred project being watched
        if readInt() != INJECTION_SALT || readString() != INJECTION_KEY {
            sendCommand(.invalid, with: nil)
            return
        }

        builder = SwiftEval()
        builder.tmpDir = tmpDir
        defer { builder = nil }

        // client spcific data for building
        if let frameworks = readString() {
            builder.frameworks = frameworks
        } else { return }

        if let arch = readString() {
            builder.arch = arch
        } else { return }

        // log errors to client
        builder.evalError = {
            (message: String) in
            self.sendCommand(.log, with:message)
            return NSError(domain:"SwiftEval", code:-1,
                           userInfo:[NSLocalizedDescriptionKey: message])
        }

        // Xcode specific config
        if let xcodeURL = NSRunningApplication.runningApplications(
            withBundleIdentifier: XcodeBundleID).first?.bundleURL {
            builder.xcodeDev = xcodeURL
                .appendingPathComponent("Contents/Developer").path
        }

        builder.projectFile = projectFile

        appDelegate.setMenuIcon("InjectionOK")
        appDelegate.lastConnection = self
        pending = []

        var lastInjected = projectInjected[projectFile]
        if lastInjected == nil {
            lastInjected = [String: Double]()
            projectInjected[projectFile] = lastInjected!
        }

        if let executable = readString(),
            appDelegate.enableWatcher.state == .on {
            let mtime = {
                (path: String) -> time_t in
                var info = stat()
                return stat(path, &info) == 0 ? info.st_mtimespec.tv_sec : 0
            }
            let executableBuild = mtime(executable)
            for (source, _) in lastInjected! {
                if !source.hasSuffix("storyboard") && !source.hasSuffix("xib") &&
                    mtime(source) > executableBuild {
                    recompileAndInject(source: source)
                }
            }
        }
        else { return }

        var pause: TimeInterval = 0.0
        var testCache = [String: [String]]()

        fileChangeHandler = {
            (changed: NSArray, ideProcPath: String) in
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
            let automatic = appDelegate.enableWatcher.state == .on
            for swiftSource in changed {
                if !self.pending.contains(swiftSource) {
                    if (now > (lastInjected?[swiftSource] ?? 0.0) + MIN_INJECTION_INTERVAL && now > pause) {
                        lastInjected![swiftSource] = now
                        projectInjected[projectFile] = lastInjected!
                        self.pending.append(swiftSource)
                        if !automatic {
                            let file = (swiftSource as NSString).lastPathComponent
                            self.sendCommand(.log,
                                with:"'\(file)' changed, type ctrl-= to inject")
                        }
                    }
                }
            }
            self.lastIdeProcPath = ideProcPath
            self.builder.lastIdeProcPath = ideProcPath
            if (automatic) {
                self.injectPending()
            }
        }
        defer { fileChangeHandler = nil }

        // start up file watchers to write generated tmpfile path to client app
        setProject(projectFile)

        DispatchQueue.main.sync {
            appDelegate.traceInclude(nil)
            appDelegate.traceExclude(nil)
        }

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
                if appDelegate.frontItem.state == .on {
                    NSWorkspace.shared
                        .open(URL(fileURLWithPath: builder.xcodeDev)
                        .appendingPathComponent("Applications/Simulator.app"))
                }
                break
            case .pause:
                pause = NSDate.timeIntervalSinceReferenceDate + Double(readString() ?? "0.0")!
                break
            case .sign:
                if !appDelegate.isSandboxed && xprobePlugin == nil {
                    sendCommand(.signed, with: "0")
                    break
                }
//                let identity = appDelegate.defaults.string(forKey: projectFile)
//                if identity != nil {
//                    NSLog("Signing with identity: \(identity!)")
//                }
                let signedOK = SignerService
                    .codesignDylib(tmpDir+"/eval"+readString()!, identity: nil)
                sendCommand(.signed, with: signedOK ? "1": "0")
                break
            case .error:
                appDelegate.setMenuIcon("InjectionError")
                NSLog("Injection error: \(readString() ?? "Uknown")")
                break;
            case .exit:
                break commandLoop
            default:
                break
            }
        }

        // client app disconnected
        fileWatchers.removeAll()
        appDelegate.traceItem.state = .off
        appDelegate.setMenuIcon("InjectionIdle")
    }

    func recompileAndInject(source: String) {
        sendCommand(.ideProcPath, with: lastIdeProcPath)
        appDelegate.setMenuIcon("InjectionBusy")
        if appDelegate.isSandboxed ||
            source.hasSuffix(".storyboard") || source.hasSuffix(".xib") {
            sendCommand(.inject, with: source)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now()+0.01) {
                if let dylib = try? self.builder.rebuildClass(oldClass: nil,
                                       classNameOrFile: source, extra: nil) {
                    self.sendCommand(.load, with: dylib)
                } else {
                    appDelegate.setMenuIcon("InjectionError")
                }
            }
        }
    }

    public func watchDirectory(_ directory: String) {
        fileWatchers.append(FileWatcher(root: directory,
                                        callback: fileChangeHandler))
        sendCommand(.watching, with: directory)
    }

    @objc public func injectPending() {
        for swiftSource in pending {
            recompileAndInject(source: swiftSource)
        }
        pending.removeAll()
    }

    @objc public func setProject(_ projectFile: String) {
        guard fileChangeHandler != nil else { return }

        builder?.projectFile = projectFile
        let projectName = URL(fileURLWithPath: projectFile)
            .deletingPathExtension().lastPathComponent
        let derivedLogs = String(format:
            "%@/Library/Developer/Xcode/DerivedData/%@-%@/Logs/Build",
                                 NSHomeDirectory(), projectName
                                    .replacingOccurrences(of: #"[\s]+"#, with:"_",
                                                   options: .regularExpression),
            XcodeHash.hashString(forPath: projectFile))
        if FileManager.default.fileExists(atPath: derivedLogs) {
            builder?.derivedLogs = derivedLogs
        }

        sendCommand(.vaccineSettingChanged,
                    with:appDelegate.vaccineConfiguration())
        fileWatchers.removeAll()
        sendCommand(.connected, with: projectFile)
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
        NSLog("\(self).deinit()")
    }
}
