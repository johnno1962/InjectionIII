//
//  Experimental.swift
//  InjectionIII
//
//  Created by User on 20/10/2020.
//  Copyright © 2020 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionIII/Experimental.swift#35 $
//

import Cocoa
import SwiftRegex

extension AppDelegate {

    @IBAction func runXprobe(_ sender: NSMenuItem) {
        if xprobePlugin == nil {
            xprobePlugin = XprobePluginMenuController()
            xprobePlugin.applicationDidFinishLaunching(
                Notification(name: Notification.Name(rawValue: "")))
            xprobePlugin.injectionPlugin = unsafeBitCast(self, to: AnyClass.self)
        }
        lastConnection?.sendCommand(.xprobe, with: "")
        windowItem.isHidden = false
    }

    @objc func evalCode(_ swift: String) {
        lastConnection?.sendCommand(.eval, with:swift)
    }

    @IBAction func callOrder(_ sender: NSMenuItem) {
        lastConnection?.sendCommand(.callOrder, with: nil)
    }

    @IBAction func fileOrder(_ sender: NSMenuItem) {
        lastConnection?.sendCommand(.fileOrder, with: nil)
    }

    @IBAction func fileReorder(_ sender: NSMenuItem) {
        lastConnection?.sendCommand(.fileReorder, with: nil)
    }

    func fileReorder(signatures: [String]) {
        var projectEncoding: String.Encoding = .utf8
        let projectURL = selectedProject.flatMap {
            URL(fileURLWithPath: $0
                .replacingOccurrences(of: ".xcworkspace", with: ".xcodeproj"))
            }
        guard let pbxprojURL = projectURL?
                .appendingPathComponent("project.pbxproj"),
            let projectSource = try? String(contentsOf: pbxprojURL,
                                            usedEncoding: &projectEncoding)
        else {
            lastConnection?.sendCommand(.log, with:
                "💉 Could not load project file \(projectURL?.path ?? "unknown").")
            return
        }

        var orders = ["AppDelegate.swift": 0]
        var order = 1
        SwiftEval.uniqueTypeNames(signatures: signatures) { typeName in
            orders[typeName+".swift"] = order
            order += 1
        }

        var newProjectSource = projectSource
        // For each PBXSourcesBuildPhase in project file
        newProjectSource[#"""
            ^\s+isa = PBXSourcesBuildPhase;
            \s+buildActionMask = \d+;
            \s+files = \(
            ((?:[^\n]+\n)*?)\#
            \s+\);

            """#.anchorsMatchLines, group: 1] = {
                (sources: String, stop) -> String in
                // reorder the lines for each file in the PBXSourcesBuildPhase
                // to bring those traced first to the front of the app binary.
                // This localises the startup code in as few pages as possible.
                return (sources[#"(\s+\S+ /\* (\S+) in Sources \*/,\n)"#]
                            as [(line: String, file: String)]).sorted(by: {
                    orders[$0.file] ?? order < orders[$1.file] ?? order
                }).map { $0.line }.joined()
            }

        DispatchQueue.main.sync {
            let project = projectURL!.lastPathComponent
            let backup = pbxprojURL.path+".preorder"
            let alert = NSAlert()
            alert.messageText = "About to reorder '\(project)'"
            alert.informativeText = "This experimental feature will modify the order of source files in memory to reduce paging on startup. There will be a backup of the project file before re-ordering at: \(backup)"
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Go ahead")
            switch alert.runModal() {
            case .alertSecondButtonReturn:
                do {
                    if !FileManager.default.fileExists(atPath: backup) {
                        try projectSource.write(toFile: backup, atomically: true,
                                                encoding: projectEncoding)
                    }
                    try newProjectSource.write(to: pbxprojURL, atomically: true,
                                               encoding: projectEncoding)
                } catch {
                    NSAlert(error: error).runModal()
                }
            default:
                break
            }
        }
    }

    /// Entry point for "Injection Goto" service
    /// - Parameters:
    ///   - pboard: NSPasteboard containing selected type [+method) name
    ///   - userData: N/A
    ///   - errorPtr: NSString describing error on error
    @objc func injectionGoto(_ pboard: NSPasteboard, userData: NSString,
                             error errorPtr: UnsafeMutablePointer<NSString>) {
        guard pboard.canReadObject(forClasses: [NSString.self], options:nil),
            let target = pboard.string(forType: .string) else { return }

        let parts = target.components(separatedBy: ".")
                        .filter { !$0.hasSuffix("init") }
        let builder = SwiftEval()
        builder.projectFile = selectedProject

        guard parts.count > 0, let (_, logsDir) =
            try? builder.determineEnvironment(classNameOrFile: "") else {
            errorPtr.pointee = "💉 Injection Goto service not availble."
            lastConnection?.sendCommand(.log, with: errorPtr.pointee as String)
            return
        }

        var className: String!, sourceFile: String?
        let tmpDir = NSTemporaryDirectory()

        for part in parts {
            let subParts = part.components(separatedBy: " ")
            className = subParts[0]
            if let (_, foundSourceFile) =
                try? builder.findCompileCommand(logsDir: logsDir,
                        classNameOrFile: className, tmpfile: tmpDir+"/eval101") {
                sourceFile = foundSourceFile
                className = subParts.count > 1 ? subParts.last : parts.last
                break
            }
        }

        className = className.replacingOccurrences(of: #"\((\S+).*"#,
                                                   with: "$1",
                                                   options: .regularExpression)

        guard sourceFile != nil,
            let sourceText = try? NSString(contentsOfFile: sourceFile!,
                                           encoding: String.Encoding.utf8.rawValue),
            let finder = try? NSRegularExpression(pattern:
                #"(?:\b(?:var|func|struct|class|enum)\s+|^[+-]\s*(?:\([^)]*\)\s*)?)(\#(className!))\b"#,
                options: [.anchorsMatchLines]) else {
            errorPtr.pointee = """
                💉 Unable to find source file for type '\(className!)' \
                using build logs.\n💉 Do you have the right project selected? \
                Try with a clean build.
                """ as NSString
            lastConnection?.sendCommand(.log, with: errorPtr.pointee as String)
            return
        }

        let match = finder.firstMatch(in: sourceText as String, options: [],
                                      range: NSMakeRange(0, sourceText.length))

        DispatchQueue.main.async {
            if let xCode = SBApplication(bundleIdentifier: XcodeBundleID),
//                xCode.activeWorkspaceDocument.path != nil,
                let doc = xCode.open(sourceFile!) as? SBObject,
                doc.selectedCharacterRange != nil,
                let range = match?.range(at: 1) {
                doc.selectedCharacterRange =
                    [NSNumber(value: range.location+1),
                     NSNumber(value: range.location+range.length)]
            } else {
                var numberOfLine = 0, index = 0

                if let range = match?.range(at: 1) {
                    while index < range.location {
                        index = NSMaxRange(sourceText
                                    .lineRange(for: NSMakeRange(index, 0)))
                        numberOfLine += 1
                    }
                }

                guard numberOfLine != 0 else { return }

                var xed = "/usr/bin/xed"
                if let xcodeURL = self.runningXcodeDevURL {
                    xed = xcodeURL
                        .appendingPathComponent("usr/bin/xed").path
                }

                let script = tmpDir+"/injection_goto.sh"
                do {
                    try "\"\(xed)\" --line \(numberOfLine) \"\(sourceFile!)\""
                        .write(toFile: script, atomically: false, encoding: .utf8)
                    chmod(script, 0o700)

                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = ["-b", "com.apple.Terminal", script]
                    task.launch()
                    task.waitUntilExit()
                } catch {
                    errorPtr.pointee = "💉 Failed to write \(script): \(error)" as NSString
                    NSLog("\(errorPtr.pointee)")
                }
            }
        }
    }

    @IBAction func prepareProject(_ sender: NSMenuItem) {
        guard let selectedProject = selectedProject else {
            let alert = NSAlert()
            alert.messageText = "Please select a project directory."
            _ = alert.runModal()
            return
        }

        let pbxURL = URL(fileURLWithPath: selectedProject)
            .appendingPathComponent("project.pbxproj")
        do {
            var pbxContents = try String(contentsOf: pbxURL)
            if !pbxContents.contains("-interposable") {
                pbxContents[#"""
                    /\* Debug \*/ = \{
                    \s+isa = XCBuildConfiguration;
                    (?:.*\n)*?(\s+)buildSettings = \{
                    ((?:.*\n)*?\1\};)
                    """#, group: 2] = """
                                        OTHER_LDFLAGS = (
                                            "-Xlinker",
                                            "-interposable",
                                            "-Xlinker",
                                            "-undefined",
                                            "-Xlinker",
                                            dynamic_lookup,
                                        );
                                        ENABLE_BITCODE = NO;
                        $2
                        """

                try pbxContents.write(to: pbxURL, atomically: false, encoding: .utf8)
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not process project file \(pbxURL): \(error)"
            _ = alert.runModal()
            return
        }

        for directory in watchedDirectories {
            prepareSwiftUI(projectRoot: URL(fileURLWithPath: directory))
        }
    }

    func prepareSwiftUI(projectRoot: URL) {
        do {
            let alert = NSAlert()
            alert.addButton(withTitle: "Go ahead")
            alert.addButton(withTitle: "Cancel")
            alert.messageText = "About to patch SwiftUI files in the currently selected project: \(projectRoot.path) for injection. This should have also added -Xlinker -interposable to your project setting's \"Other Linker Flags\"."
            switch alert.runModal() {
            case .alertSecondButtonReturn:
                return
            default:
                break
            }

            for file in FileManager.default.enumerator(atPath: projectRoot.path)! {
                guard let file = file as? String, file.hasSuffix(".swift"),
                      !file.hasPrefix("Packages") else {
                    continue
                }
                let fileURL = projectRoot.appendingPathComponent(file)
                guard let original = try? String(contentsOf: fileURL) else {
                    continue
                }

                var patched = original
                patched[#"""
                    ^((\s+)(public )?(var body:|func body\([^)]*\) -\>) some View \{\n\#
                    (\2(?!    (if|switch) )\s+(?!\.eraseToAnyView|ForEach)\S.*\n|\n)+)(?<!#endif\n)\2\}\n
                    """#.anchorsMatchLines] = """
                    $1$2    .eraseToAnyView()
                    $2}

                    $2#if DEBUG
                    $2@ObservedObject var iO = injectionObserver
                    $2#endif

                    """

                if patched.contains("class AppDelegate") ||
                    patched.contains("@main") && !patched.contains("InjectionIII") {
                    patched += """

                        #if DEBUG
                        private var loadInjection: () = {
                            #if os(macOS)
                            let bundleName = "macOSInjection.bundle"
                            #elseif os(tvOS)
                            let bundleName = "tvOSInjection.bundle"
                            #elseif targetEnvironment(simulator)
                            let bundleName = "iOSInjection.bundle"
                            #else
                            let bundleName = "maciOSInjection.bundle"
                            #endif
                            Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/"+bundleName)!.load()
                        }()

                        import Combine

                        public let injectionObserver = InjectionObserver()

                        public class InjectionObserver: ObservableObject {
                            @Published var injectionNumber = 0
                            var cancellable: AnyCancellable? = nil
                            let publisher = PassthroughSubject<Void, Never>()
                            init() {
                                cancellable = NotificationCenter.default.publisher(for:
                                    Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))
                                    .sink { [weak self] change in
                                    self?.injectionNumber += 1
                                    self?.publisher.send()
                                }
                            }
                        }

                        extension View {
                            public func eraseToAnyView() -> some View {
                                _ = loadInjection
                                return AnyView(self)
                            }
                            public func onInjection(bumpState: @escaping () -> ()) -> some View {
                                return self
                                    .onReceive(injectionObserver.publisher, perform: bumpState)
                                    .eraseToAnyView()
                            }
                        }
                        #else
                        extension View {
                            public func eraseToAnyView() -> some View { return self }
                            public func onInjection(bumpState: @escaping () -> ()) -> some View {
                                return self
                            }
                        }
                        #endif

                        """
                }

                if patched != original {
                    try patched.write(to: fileURL,
                                      atomically: false, encoding: .utf8)
                }
            }
        }
        catch {
            print(error)
        }
    }
}
