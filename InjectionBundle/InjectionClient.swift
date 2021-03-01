//
//  InjectionClient.swift
//  InjectionIII
//
//  Created by John Holdsworth on 02/24/2021.
//  Copyright © 2021 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionBundle/InjectionClient.swift#7 $
//
//  Client app side of HotReloading started by +load
//  method in HotReloadingGuts/ClientBoot.mm
//

import Foundation
import SwiftTrace
#if SWIFT_PACKAGE
import SwiftTraceGuts
import HotReloadingGuts
#endif

@objc(InjectionClient)
public class InjectionClient: SimpleSocket {

    public override func runInBackground() {
        let builder = SwiftInjectionEval.sharedInstance()
        builder.tmpDir = NSTemporaryDirectory()
        
        write(INJECTION_SALT)
        write(INJECTION_KEY)

        let frameworksPath = Bundle.main.privateFrameworksPath!
        write(builder.tmpDir)
        write(builder.arch)
        write(Bundle.main.executablePath!)

        builder.tmpDir = readString() ?? "/tmp"

        var frameworkPaths = [String: String]()
        let isPlugin = builder.tmpDir == "/tmp"
        if (!isPlugin) {
            var frameworks = [String]()
            var sysFrameworks = [String]()
            let bundleFrameworks = frameworksPath

            for i in stride(from: _dyld_image_count()-1, through: 0, by: -1) {
                let imageName = _dyld_get_image_name(i)!
                if strstr(imageName, ".framework/") == nil {
                    continue
                }
                let imagePath = String(cString: imageName)
                let frameworkName = URL(fileURLWithPath: imagePath).lastPathComponent
                frameworkPaths[frameworkName] = imagePath
                if String(cString: imageName).hasPrefix(bundleFrameworks) {
                    frameworks.append(frameworkName)
                } else {
                    sysFrameworks.append(frameworkName)
                }
            }

            writeCommand(InjectionResponse.frameworkList.rawValue, with:
                            frameworks.joined(separator: FRAMEWORK_DELIMITER))
            write(sysFrameworks.joined(separator: FRAMEWORK_DELIMITER))
            write(SwiftInjection.packageNames()
                    .joined(separator: FRAMEWORK_DELIMITER))
        }

        processCommands(builder: builder, frameworkPaths)

        print("\(APP_PREFIX)\(APP_NAME) disconnected.")
    }

    func processCommands(builder: SwiftEval, _ frameworkPaths: [String: String]) {
        var codesignStatusPipe = [Int32](repeating: 0, count: 2)
        pipe(&codesignStatusPipe)
        let reader = SimpleSocket(socket: codesignStatusPipe[0])
        let writer = SimpleSocket(socket: codesignStatusPipe[1])

        builder.signer = { dylib -> Bool in
            self.writeCommand(InjectionResponse.sign.rawValue, with: dylib)
            return reader.readString() == "1"
        }

        while let command = InjectionCommand(rawValue: readInt()),
              command != .EOF {
            switch command {
            case .vaccineSettingChanged:
                if let data = readString()?.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    builder.vaccineEnabled = json[UserDefaultsVaccineEnabled] as! Bool
                }
            case .connected:
                builder.projectFile = readString() ?? "Missing project"
                builder.derivedLogs = nil;
                print("\(APP_PREFIX)\(APP_NAME) connected \(builder.projectFile!)")
            case .watching:
                print("\(APP_PREFIX)Watching files under \(readString() ?? "Missing directory")")
            case .log:
                print(APP_PREFIX+(readString() ?? "Missing log message"))
            case .ideProcPath:
                builder.lastIdeProcPath = readString() ?? ""
            case .invalid:
                print("\(APP_PREFIX)⚠️ Server has rejected your connection. Are you running start_daemon.sh from the right directory? ⚠️")
            case .quietInclude:
                SwiftTrace.traceFilterInclude = readString()
            case .include:
                SwiftTrace.traceFilterInclude = readString()
                filteringChanged()
            case .exclude:
                SwiftTrace.traceFilterExclude = readString()
                filteringChanged()
            case .feedback:
                SwiftInjection.traceInjection = readString() == "1"
            case .lookup:
                SwiftTrace.typeLookup = readString() == "1"
                if SwiftTrace.swiftTracing {
                    print("\(APP_PREFIX)Discovery of target app's types switched \(SwiftTrace.typeLookup ? "on" : "off")");
                }
            case .trace:
                SwiftTrace.traceMainBundleMethods()
                print("\(APP_PREFIX)Added trace to non-final methods of classes in app bundle")
            case .untrace:
                SwiftTrace.removeAllTraces()
            case .traceUI:
                SwiftTrace.traceMainBundleMethods()
                SwiftTrace.traceMainBundle()
                print("\(APP_PREFIX)Added trace to methods in main bundle")
            case .traceUIKit:
                DispatchQueue.main.sync {
                    let OSView: AnyClass = (objc_getClass("UIView") ??
                        objc_getClass("NSView")) as! AnyClass
                    print("\(APP_PREFIX)Adding trace to the framework containg \(OSView), this will take a while...")
                    SwiftTrace.traceBundle(containing: OSView)
                    print("\(APP_PREFIX)Completed adding trace.")
                }
            case .traceSwiftUI:
                if let AnyText = swiftUIBundlePath() {
                    print("\(APP_PREFIX)Adding trace to SwiftUI calls.")
                    SwiftTrace.interposeMethods(inBundlePath:AnyText, packageName:nil)
                    filteringChanged()
                } else {
                    print("\(APP_PREFIX)Your app doesn't seem to use SwiftUI.")
                }
            case .traceFramework:
                let frameworkName = readString() ?? "Misssing framework"
                if let frameworkPath = frameworkPaths[frameworkName] {
                    print("\(APP_PREFIX)Tracing %s\n", frameworkPath)
                    SwiftTrace.interposeMethods(inBundlePath:frameworkPath, packageName:nil)
                    SwiftTrace.trace(bundlePath:frameworkPath)
                } else {
                    print("\(APP_PREFIX)Tracing package \(frameworkName)")
                    let mainBundlePath = Bundle.main.executablePath ?? "Missing"
                    SwiftTrace.interposeMethods(inBundlePath:mainBundlePath,
                                                packageName:frameworkName)
                }
                filteringChanged()
            case .uninterpose:
                SwiftTrace.revertInterposes()
                SwiftTrace.removeAllTraces()
                print("\(APP_PREFIX)Removed all traces (and injections).")
                break;
            case .stats:
                let top = 200;
                print("""

                    \(APP_PREFIX)Sorted top \(top) elapsed time/invocations by method
                    \(APP_PREFIX)=================================================
                    """)
                SwiftInjection.dumpStats(top:top)
                needsTracing()
            case .callOrder:
                print("""

                    \(APP_PREFIX)Function names in the order they were first called:
                    \(APP_PREFIX)===================================================
                    """)
                for signature in SwiftInjection.callOrder() {
                    print(signature)
                }
                needsTracing()
            case .fileOrder:
                print("""
                    \(APP_PREFIX)Source files in the order they were first referenced:
                    \(APP_PREFIX)=====================================================
                    \(APP_PREFIX)(Order the source files should be compiled in target)
                    """)
                SwiftInjection.fileOrder()
                needsTracing()
            case .fileReorder:
                writeCommand(InjectionResponse.callOrderList.rawValue,
                             with:SwiftInjection.callOrder().joined(separator: CALLORDER_DELIMITER))
                needsTracing()
            case .signed:
                writer.write(readString() ?? "0")
            default:
                processOnMainThread(command: command, builder: builder)
            }
        }
    }

    func processOnMainThread(command: InjectionCommand, builder: SwiftEval) {
        guard let changed = self.readString() else { return }
        DispatchQueue.main.async {
            var err: String?
            switch command {
            case .load:
                do {
                    try SwiftInjection.inject(tmpfile: changed)
                } catch {
                    err = error.localizedDescription
                }
            case .inject:
                if changed.hasSuffix("storyboard") || changed.hasSuffix("xib") {
                    if !NSObject.injectUI(changed) {
                        err = "Interface injection failed"
                    }
                } else {
                    SwiftInjection.inject(oldClass:nil, classNameOrFile:changed)
                }
            case .xprobe:
                Xprobe.connect(to: nil, retainObjects:true)
                Xprobe.search("")
            case .eval:
                let parts = changed.components(separatedBy:"^")
                guard let pathID = Int(parts[0]) else { break }
                self.writeCommand(InjectionResponse.pause.rawValue, with:"5")
                if let object = (xprobePaths[pathID] as? XprobePath)?
                    .object() as? NSObject, object.responds(to: Selector(("swiftEvalWithCode:"))),
                   let code = (parts[3] as NSString).removingPercentEncoding,
                   object.swiftEval(code: code) {
                } else {
                    print("\(APP_PREFIX)Xprobe: Eval only works on NSObject subclasses where the source file has the same name as the class and is in your project.")
                }
                Xprobe.write("$('BUSY\(pathID)').hidden = true; ")
            default:
                print("\(APP_PREFIX)Unimplemented command: \(command.rawValue)")
            }
            let response: InjectionResponse = err != nil ? .error : .complete
            self.writeCommand(response.rawValue, with: err)
        }
    }

    func needsTracing() {
        if !SwiftTrace.swiftTracing {
            print("\(APP_PREFIX)⚠️ You need to have traced something to gather stats.")
        }
    }

    func filteringChanged() {
        if SwiftTrace.swiftTracing {
            let exclude = SwiftTrace.traceFilterExclude
            if let include = SwiftTrace.traceFilterInclude {
                print(String(format: exclude != nil ?
                   "\(APP_PREFIX)Filtering trace to include methods matching '%@' but not '%@'." :
                   "\(APP_PREFIX)Filtering trace to include methods matching '%@'.",
                   include, exclude != nil ? exclude! : ""))
            } else {
                print(String(format: exclude != nil ?
                   "\(APP_PREFIX)Filtering trace to exclude methods matching '%@'." :
                   "\(APP_PREFIX)Not filtering trace (Menu Item: 'Set Filters')",
                   exclude != nil ? exclude! : ""))
            }
        }
    }
}
