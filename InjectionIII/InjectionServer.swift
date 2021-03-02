//
//  InjectionServer.swift
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionIII/InjectionServer.swift#92 $
//

import Cocoa
#if SWIFT_PACKAGE
import injectiondGuts
#endif

let commandQueue = DispatchQueue(label: "InjectionCommand")
let compileQueue = DispatchQueue(label: "InjectionCompile")

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

        // tell client app the inferred project being watched
        NSLog("Connection for project file: \(projectFile)")

        if readInt() != INJECTION_SALT || readString() != INJECTION_KEY {
            NSLog("*** Error: SALT or KEY invalid. Are you running start_daemon.sh or InjectionIII.app from the right directory?")
            write("/tmp")
            write(InjectionCommand.invalid.rawValue)
            return
        }

        builder = SwiftEval()
        defer {
            builder.signer = nil
            builder = nil
        }

        // client specific data for building
        if let frameworks = readString() {
            builder.frameworks = frameworks
        } else { return }

        if let arch = readString() {
            builder.arch = arch
        } else { return }

        if appDelegate.isSandboxed {
            builder.tmpDir = NSTemporaryDirectory()
        } else {
            builder.tmpDir = builder.frameworks
        }
        write(builder.tmpDir)

        // log errors to client
        builder.evalError = {
            (message: String) in
            NSLog("%@", message)
            self.sendCommand(.log, with:message)
            return NSError(domain:"SwiftEval", code:-1,
                           userInfo:[NSLocalizedDescriptionKey: message])
        }

        builder.signer = {
            let identity = appDelegate.defaults.string(forKey: projectFile)
            if identity != nil {
                NSLog("Signing with identity: \(identity!)")
            }
            return SignerService.codesignDylib(
                self.builder.tmpDir+"/eval"+$0, identity: identity)
        }

        // Xcode specific config
        if let xcodeDevURL = appDelegate.runningXcodeDevURL {
            builder.xcodeDev = xcodeDevURL.path
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

        guard let executable = readString() else { return }
        if false && appDelegate.enableWatcher.state == .on {
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
        if projectFile.contains("/Desktop/") || projectFile.contains("/Documents/") {
            sendCommand(.log, with: "\(APP_PREFIX)⚠️ Your project file seems to be in the Desktop or Documents folder and may prevent \(APP_NAME) working as it has special permissions.")
        }

        DispatchQueue.main.sync {
            appDelegate.updateTraceInclude(nil)
            appDelegate.updateTraceExclude(nil)
            appDelegate.toggleFeedback(nil)
            appDelegate.toggleLookup(nil)
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
            case .frameworkList:
                appDelegate.setFrameworks(readString() ?? "",
                                          menuTitle: "Trace Framework")
                appDelegate.setFrameworks(readString() ?? "",
                                          menuTitle: "Trace SysInternal")
                appDelegate.setFrameworks(readString() ?? "",
                                          menuTitle: "Trace Package")
            case .complete:
                appDelegate.setMenuIcon("InjectionOK")
                if appDelegate.frontItem.state == .on {
                    print(executable)
                    let appToOrderFront: URL
                    if executable.contains("/MacOS/") {
                        appToOrderFront = URL(fileURLWithPath: executable)
                            .deletingLastPathComponent()
                            .deletingLastPathComponent()
                            .deletingLastPathComponent()
                    } else {
                        appToOrderFront = URL(fileURLWithPath: builder.xcodeDev)
                            .appendingPathComponent("Applications/Simulator.app")
                    }
                    NSWorkspace.shared.open(appToOrderFront)
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
                sendCommand(.signed, with: builder
                                .signer!(readString() ?? "") ? "1": "0")
            case .callOrderList:
                if let calls = readString()?
                    .components(separatedBy: CALLORDER_DELIMITER) {
                    appDelegate.fileReorder(signatures: calls)
                }
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
            #if SWIFT_PACKAGE
            try? source.write(toFile: "/tmp/injecting_storyboard.txt",
                              atomically: false, encoding: .utf8)
            #endif
            sendCommand(.inject, with: source)
        } else {
            compileQueue.async {
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
        #if !SWIFT_PACKAGE
        let projectName = URL(fileURLWithPath: projectFile)
            .deletingPathExtension().lastPathComponent
        let derivedLogs = String(format:
            "%@/Library/Developer/Xcode/DerivedData/%@-%@/Logs/Build",
                                 NSHomeDirectory(), projectName
                                    .replacingOccurrences(of: #"[\s]+"#, with:"_",
                                                   options: .regularExpression),
            XcodeHash.hashString(forPath: projectFile))
        #else
        let derivedLogs = appDelegate.derivedLogs ?? "No derived logs"
        #endif
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
