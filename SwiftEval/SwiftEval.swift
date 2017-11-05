//
//  SwiftEval.swift
//  SwiftEval
//
//  Created by John Holdsworth on 02/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/SwiftEval/SwiftEval.swift#3 $
//
//  Basic implementation of ra Swift "eval()" including the
//  mechanics of recompiling a class and loading the new
//  version.
//

#if arch(x86_64) // simulator/macOS only
import Foundation

private func debug(_ str: String) {
//    print(str)
}

/// Error handler
public var evalError = {
    (_ err: String) -> AnyClass? in
    print("** \(err) **")
    return nil
}

extension NSObject {

    private static var lastEvalByClass = [String: String]()

    /// eval() for String value
    public func eval(_ expression: String) -> String {
        return eval("\"" + expression + "\"", String.self)
    }

    /// eval() for value of any type
    public func eval<T>(_ expression: String, _ type: T.Type) -> T {
        let oldClass: AnyClass = object_getClass(self)!
        let className = "\(oldClass)"
        let extra = """

            extension \(className) {

                @objc dynamic override func evalImpl(_ptr: UnsafeMutableRawPointer) {
                    let _ptr = _ptr.assumingMemoryBound(to: \(type).self)
                    _ptr.pointee = \(expression)
                }

            }

            """

        // update evalImpl to implement expression

        if NSObject.lastEvalByClass[className] != expression,
            let newClass = SwiftEval.rebuildClass(oldClass: oldClass, className: className, extra: extra) {

            // swizzle new version of evalImpl onto class

            if let newMethod = class_getInstanceMethod(newClass, #selector(evalImpl(_ptr:))) {
                class_replaceMethod(oldClass, #selector(evalImpl(_ptr:)),
                                    method_getImplementation(newMethod),
                                    method_getTypeEncoding(newMethod))

                NSObject.lastEvalByClass[className] = expression
            }
        }

        // call patched evalImpl to realise expression

        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        bzero(ptr, MemoryLayout<T>.size)
        if NSObject.lastEvalByClass[className] == expression {
            evalImpl(_ptr: ptr)
        }
        let out = ptr.pointee
        ptr.deallocate(capacity: 1)
        return out
    }

    @objc dynamic func evalImpl(_ptr _: UnsafeMutableRawPointer) {
        print("NSObject.evalImpl() called - no subclass implementation loaded")
    }
}

extension String {
    subscript(range: NSRange) -> String? {
        return range.location != NSNotFound ? String(self[Range(range, in: self)!]) : nil
    }
}

class SwiftEval {

    static var dylibNumber = 0
    static var compileByClass = [String: String]()

    static func rebuildClass(oldClass: AnyClass, className: String, extra: String?) -> AnyClass? {
        let sourceURL = URL(fileURLWithPath: #file)
        guard let derivedData = findDerivedData(url: sourceURL) else {
            return evalError("Could not locate derived data")
        }
        guard let (projectFile, logsDir) = findProject(for: sourceURL, derivedData: derivedData) else {
            return evalError("Could not locate containg project")
        }

        // locate compile command for class

        let regexp = "^    /.+? -primary-file (\"([^\"]+?/\(className)\\.swift)\"|(\\S+?/\(className)\\.swift)) "

        guard var compileCommand = compileByClass[className] ?? {
            () -> String? in

            guard shell(command: """
                # search through build logs in reverse order
                for log in `ls -t "\(logsDir.path)/"*.xcactivitylog`; do
                    echo "Scanning $log"
                    # grep log for build of class source
                    /usr/bin/gunzip <"$log" | /usr/bin/tr '\\r' '\\n' | \
                    /usr/bin/grep -E '\(regexp)' >/tmp/eval.sh && exit 0;
                done;
                exit 1
                """) else {
                return nil
            }
            
            var compileCommand = try! String(contentsOfFile: "/tmp/eval.sh")
            compileCommand = compileCommand.components(separatedBy: " -o ")[0]
            compileByClass[className] = compileCommand
            return compileCommand
        }() else {
            return evalError("Could not locate compile command for \(className)")
        }

        // extract full path to file from compile command

        let fileExtractor = try! NSRegularExpression(pattern: regexp, options: [])
        guard let matches = fileExtractor.firstMatch(in: compileCommand, options: [],
                                                     range: NSMakeRange(0, compileCommand.utf16.count)),
            let sourceFile = compileCommand[matches.range(at: 2)] ??
                             compileCommand[matches.range(at: 3)] else {
                    return evalError("Could not locate source file")
        }
        debug(sourceFile)

        // load and patch class source if there is an extension to add

        let filemgr = FileManager.default, backup = sourceFile + ".tmp"
        if extra != nil {
            guard var classSource = (try? String(contentsOfFile: sourceFile)) else {
                return evalError("Could not load source file")
            }

            let changesTag = "// extension added to implement eval"
            classSource = classSource.components(separatedBy: "\n\(changesTag)\n")[0] + """

                \(changesTag)
                \(extra!)

                """

            debug(classSource)

            // backup original and compile patched class source

            if !filemgr.fileExists(atPath: backup) {
                try! filemgr.moveItem(atPath: sourceFile, toPath: backup)
            }
            try! classSource.write(toFile: sourceFile, atomically: true, encoding: .utf8)
        }

        defer {
            if extra != nil {
                try! filemgr.removeItem(atPath: sourceFile)
                try! filemgr.moveItem(atPath: backup, toPath: sourceFile)
            }
        }

        let projectDir = projectFile.deletingLastPathComponent().path

        guard shell(command: """
            cd "\(projectDir)" && \(compileCommand) -o /tmp/eval.o >/tmp/eval.log 2>&1 || (cat /tmp/eval.log && exit 1)
            """) else {
            return evalError("Re-compilation failed\n\(try! String(contentsOfFile: "/tmp/eval.log"))")
        }

        // link object to create dynamic library

        dylibNumber += 1
        let dylib = "/tmp/eval\(dylibNumber).dylib"
        let xcode = "/Applications/Xcode.app/Contents/Developer"

        #if os(iOS)
        let osSpecific = "-isysroot \(xcode)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk -mios-simulator-version-min=11.1 -L\(xcode)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator"
        let frameworkPath = Bundle.main.bundlePath + "/Frameworks"
        #else
        let osSpecific = "-isysroot \(xcode)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -mmacosx-version-min=10.12 -L\(xcode)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx"
        let frameworkPath = Bundle.main.bundlePath + "/Contents/Frameworks"
        #endif

        guard shell(command: """
            \(xcode)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -arch x86_64 -bundle \(osSpecific) -dead_strip -Xlinker -objc_abi_version -Xlinker 2 -fobjc-arc /tmp/eval.o -L \(frameworkPath) -F \(frameworkPath) -rpath \(frameworkPath) -undefined dynamic_lookup -o \(dylib)
            """) else {
            return evalError("Link failed")
        }

        #if os(iOS)
        // have to delegate code signing to macOS "signer" service
        guard (try? String(contentsOf: URL(string: "http://localhost:8899" + dylib)!)) != nil else {
            return evalError("Codesign failed. Is 'signer' daemon running?")
        }
        #else
        guard shell(command: """
            export CODESIGN_ALLOCATE=\(xcode)/Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate; codesign --force -s '-' "\(dylib)"
            """) else {
            return evalError("Codesign failed")
        }
        #endif

        // load patch .dylib into process with new version of class

        guard let dl = dlopen(dylib, RTLD_NOW) else {
            return evalError("dlopen() error: \(String(cString: dlerror()))")
        }

        // find patched version of class using symbol for existing

        var info = Dl_info()
        guard dladdr(unsafeBitCast(oldClass, to: UnsafeRawPointer.self), &info) != 0 else {
            return evalError("Could not locate class symbol")
        }

        debug(String(cString: info.dli_sname))
        guard let newSymbol = dlsym(dl, info.dli_sname) else {
            return evalError("Could not locate newly loaded class symbol")
        }

        return unsafeBitCast(newSymbol, to: AnyClass.self)
    }

    static func findDerivedData(url: URL) -> URL? {
        let dir = url.deletingLastPathComponent()
        if dir.path == "/" {
            return nil
        }

        let derived = dir.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        if FileManager.default.fileExists(atPath: derived.path) {
            return derived
        }

        return findDerivedData(url: dir)
    }

    static func findProject(for source: URL, derivedData: URL) -> (URL, URL)? {
        let dir = source.deletingLastPathComponent()
        if dir.path == "/" {
            return nil
        }

        if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path),
            let project = file(withExt: "xcworkspace", in: files) ?? file(withExt: "xcodeproj", in: files),
            let logs = logDir(project: dir.appendingPathComponent(project), derivedData: derivedData) {
            return (dir.appendingPathComponent(project), logs)
        }

        return findProject(for: dir, derivedData: derivedData)
    }

    static func file(withExt ext: String, in files: [String]) -> String? {
        return files.first { URL(fileURLWithPath: $0).pathExtension == ext }
    }

    static func logDir(project: URL, derivedData: URL) -> URL? {
        let filemgr = FileManager.default
        let projectPrefix = project.deletingPathExtension()
            .lastPathComponent.replacingOccurrences(of: " ", with: "_")
        let relativeDerivedData = project.deletingLastPathComponent()
            .appendingPathComponent("DerivedData/\(projectPrefix)/Logs/Build")

        func mtime(_ path: String) -> time_t {
            var info = stat()
            return stat(path, &info) == 0 ? info.st_mtimespec.tv_sec : 0
        }

        return ((try? filemgr.contentsOfDirectory(atPath: derivedData.path))?
            .filter { $0.starts(with: projectPrefix + "-") }
            .map { derivedData.appendingPathComponent($0 + "/Logs/Build") }
            ?? [] + [relativeDerivedData])
            .filter { filemgr.fileExists(atPath: $0.path) }
            .sorted { mtime($0.path) > mtime($1.path) }
            .first
    }

    static func shell(command: String) -> Bool {
        debug(command)

        let pid = fork()
        if pid == 0 {
            var args = Array<UnsafeMutablePointer<Int8>?>(repeating: nil, count: 4)
            args[0] = strdup("/bin/bash")!
            args[1] = strdup("-c")!
            args[2] = strdup(command)!
            args.withUnsafeMutableBufferPointer {
                _ = execve("/bin/bash", $0.baseAddress!, nil) // _NSGetEnviron().pointee)
                fatalError("execve() fails \(String(cString: strerror(errno)))")
            }
        }

        var status: Int32 = 0
        while waitpid(pid, &status, 0) == -1 {}
        return status >> 8 == EXIT_SUCCESS
    }
}

@_silgen_name("fork")
func fork() -> Int32
@_silgen_name("_NSGetEnviron")
func _NSGetEnviron() -> UnsafePointer<UnsafePointer<UnsafeMutablePointer<Int8>?>?>!
#endif
