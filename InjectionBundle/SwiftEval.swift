//
//  SwiftEval.swift
//  InjectionBundle
//
//  Created by John Holdsworth on 02/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionBundle/SwiftEval.swift#50 $
//
//  Basic implementation of a Swift "eval()" including the
//  mechanics of recompiling a class and loading the new
//  version used in the associated injection version.
//

#if arch(x86_64) // simulator/macOS only
import Foundation

private func debug(_ str: String) {
//    print(str)
}

/// Error handler
public var evalError = {
    (_ message: String) -> Error in
    print("*** \(message) ***")
    _ = SwiftEval.instance.signer?("ERROR \(message)")
    return NSError(domain: "SwiftEval", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
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

        if NSObject.lastEvalByClass[className] != expression {
            do {
                if let newClass = try SwiftEval.instance.rebuildClass(oldClass: oldClass, classNameOrFile: className, extra: extra).first {
                    if NSStringFromClass(newClass) != NSStringFromClass(oldClass) {
                        NSLog("Class names different. Have the right class been loaded?")
                    }

                    // swizzle new version of evalImpl onto class

                    if let newMethod = class_getInstanceMethod(newClass, #selector(evalImpl(_ptr:))) {
                        class_replaceMethod(oldClass, #selector(evalImpl(_ptr:)),
                                            method_getImplementation(newMethod),
                                            method_getTypeEncoding(newMethod))

                        NSObject.lastEvalByClass[className] = expression
                    }
                }
            }
            catch {
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

fileprivate extension String {
    subscript(range: NSRange) -> String? {
        return range.location != NSNotFound ? String(self[Range(range, in: self)!]) : nil
    }
    func escaping(_ chars: String, _ template: String = "\\$0") -> String {
        return self.replacingOccurrences(of: "[\(chars)]",
            with: template.replacingOccurrences(of: "\\", with: "\\\\"), options: [.regularExpression])
    }
}

@objc
public class SwiftEval: NSObject {

    static var instance = SwiftEval()

    @objc public class func sharedInstance() -> SwiftEval {
        return instance
    }

    @objc public var signer: ((_: String) -> Bool)?

    var injectionNumber = 0
    var compileByClass = [String: (String, String)]()

    func rebuildClass(oldClass: AnyClass?, classNameOrFile: String, extra: String?) throws -> [AnyClass] {
        let sourceURL = URL(fileURLWithPath: classNameOrFile.contains("/") ? "/" + classNameOrFile : #file)
        guard let derivedData = findDerivedData(url: sourceURL) else {
            throw evalError("Could not locate derived data. Is the project under you home directory?")
        }
        guard let (projectFile, logsDir) = findProject(for: sourceURL, derivedData: derivedData) else {
            throw evalError("Could not locate containg project or it's logs.")
        }

        // locate compile command for class

        injectionNumber += 1
        let tmpfile = "/tmp/eval\(injectionNumber)"

        guard var (compileCommand, sourceFile) = try compileByClass[classNameOrFile] ??
            findCompileCommand(logsDir: logsDir, classNameOrFile: classNameOrFile, tmpfile: tmpfile) else {
            throw evalError("""
                Could not locate compile command for \(classNameOrFile)
                Try a clean build. There are also restrictions on characters allowed in paths.
                """)
        }

        compileByClass[classNameOrFile] = (compileCommand, sourceFile)

        // load and patch class source if there is an extension to add

        let filemgr = FileManager.default, backup = sourceFile + ".tmp"
        if extra != nil {
            guard var classSource = try? String(contentsOfFile: sourceFile) else {
                throw evalError("Could not load source file \(sourceFile)")
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

        print("Compiling \(sourceFile)")

        guard shell(command: """
                time (cd "\(projectDir.escaping("$"))" && \(compileCommand) -o \(tmpfile).o >\(tmpfile).log 2>&1)
                """) else {
            throw evalError("Re-compilation failed (\(tmpfile).sh)\n\(try! String(contentsOfFile: "\(tmpfile).log"))")
        }

        // link resulting object file to create dynamic library

        let xcode = "/Applications/Xcode.app/Contents/Developer"
        let toolchain = ((try! NSRegularExpression(pattern: "\\s*(\\S+?\\.xctoolchain)", options: []))
            .firstMatch(in: compileCommand, options: [], range: NSMakeRange(0, compileCommand.utf16.count))?
            .range(at: 1)).flatMap { compileCommand[$0] } ?? "\(xcode)/Toolchains/XcodeDefault.xctoolchain"

        #if os(iOS)
        let osSpecific = "-isysroot \(xcode)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk -mios-simulator-version-min=11.1 -L\(toolchain)/usr/lib/swift/iphonesimulator -undefined dynamic_lookup"// -Xlinker -bundle_loader -Xlinker \"\(Bundle.main.executablePath!)\""
        let frameworkPath = Bundle.main.bundlePath + "/Frameworks"
        #elseif os(tvOS)
        let osSpecific = "-isysroot \(xcode)/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk -mtvos-simulator-version-min=11.1 -L\(toolchain)/usr/lib/swift/appletvsimulator -undefined dynamic_lookup"// -Xlinker -bundle_loader -Xlinker \"\(Bundle.main.executablePath!)\""
        let frameworkPath = Bundle.main.bundlePath + "/Frameworks"
        #else
        let osSpecific = "-isysroot \(xcode)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -mmacosx-version-min=10.12 -L\(toolchain)/usr/lib/swift/macosx -undefined dynamic_lookup"
        let frameworkPath = Bundle.main.bundlePath + "/Contents/Frameworks"
        #endif

        guard shell(command: """
            \(xcode)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -arch x86_64 -bundle \(osSpecific) -dead_strip -Xlinker -objc_abi_version -Xlinker 2 -fobjc-arc \(tmpfile).o -L "\(frameworkPath)" -F "\(frameworkPath)" -rpath "\(frameworkPath)" -o \(tmpfile).dylib
            """) else {
            throw evalError("Link failed")
        }

        // codesign dylib

        if signer != nil {
            guard signer!("SIGN \(tmpfile).dylib") else {
                throw evalError("Codesign failed")
            }
        }
        else {
            #if os(iOS)
            // have to delegate code signing to macOS "signer" service
            guard (try? String(contentsOf: URL(string: "http://localhost:8899\(tmpfile).dylib")!)) != nil else {
                throw evalError("Codesign failed. Is 'signer' daemon running?")
            }
            #else
            guard shell(command: """
                export CODESIGN_ALLOCATE=\(xcode)/Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate; codesign --force -s '-' "\(tmpfile).dylib"
                """) else {
                throw evalError("Codesign failed")
            }
            #endif
        }

        // load patch .dylib into process with new version of class

        print("Loading \(tmpfile).dylib. (Ignore any duplicate class warning)")
        guard let dl = dlopen("\(tmpfile).dylib", RTLD_NOW) else {
            throw evalError("dlopen() error: \(String(cString: dlerror()))")
        }

        if oldClass != nil {
            // find patched version of class using symbol for existing

            var info = Dl_info()
            guard dladdr(unsafeBitCast(oldClass, to: UnsafeRawPointer.self), &info) != 0 else {
                throw evalError("Could not locate class symbol")
            }

            debug(String(cString: info.dli_sname))
            guard let newSymbol = dlsym(dl, info.dli_sname) else {
                throw evalError("Could not locate newly loaded class symbol")
            }

            return [unsafeBitCast(newSymbol, to: AnyClass.self)]
        }
        else {
            // grep out symbols for classes being injected from object file
            try injectGenerics(xcode: xcode, tmpfile: tmpfile, handle: dl)

            guard shell(command: """
                \(xcode)/Toolchains/XcodeDefault.xctoolchain/usr/bin/nm \(tmpfile).o | grep -E ' S _OBJC_CLASS_\\$_| __T0.*CN$' | awk '{print $3}' >\(tmpfile).classes
                """) else {
                throw evalError("Could not list class symbols")
            }
            guard var symbols = (try? String(contentsOfFile: "\(tmpfile).classes"))?.components(separatedBy: "\n") else {
                throw evalError("Could not load class symbol list")
            }

            symbols.removeLast()
            return Set(symbols.flatMap { dlsym(dl, String($0.dropFirst())) }).map { unsafeBitCast($0, to: AnyClass.self) }
        }
    }

    func findCompileCommand(logsDir: URL, classNameOrFile: String, tmpfile: String) throws -> (compileCommand: String, sourceFile: String)? {
        // path to project can contain spaces and '$&(){}
        // Objective-C paths can only contain space and '
        // project file itself can only contain spaces
        // (logs of new build system escape ', $ and ")
        let swiftEscaped = "\\Q\(classNameOrFile.escaping("'$", "\\E\\\\*$0\\Q"))\\E\\.(?:swift|mm?)"
        let objcEscaped = "\\Q\(classNameOrFile.escaping(" '"))\\E\\.(?:swift|mm?)"
        let regexp = " -(?:primary-file|c(?<! -frontend -c)) (?:\\\\?\"([^\"]*?/\(swiftEscaped))\\\\?\"|(\\S*?/\(objcEscaped))) "

        // messy but fast
        guard shell(command: """
            # search through build logs, most recent first
            for log in `ls -t "\(logsDir.path)/"*.xcactivitylog`; do
                echo "Scanning $log"
                /usr/bin/env perl <(cat <<'PERL'
                    use JSON::PP;
                    use English;
                    use strict;

                    # line separator in Xcode logs
                    $INPUT_RECORD_SEPARATOR = "\\r";

                    # format is gzip
                    open GUNZIP, "/usr/bin/gunzip <\\"$ARGV[0]\\" 2>/dev/null |" or die;

                    # grep the log until there is a match
                    while (defined (my $line = <GUNZIP>)) {
                        if ($line =~ m@\(regexp.escaping("\"$"))@o) {
                            # found compile command
                            # may need to extract file list
                            if ($line =~ / -filelist /) {
                                while (defined (my $line2 = <GUNZIP>)) {
                                    if (my($filemap) = $line2 =~ / -output-file-map ([^ \\\\]+(?:\\\\ [^ \\\\]+)*) / ) {
                                        $filemap =~ s/\\\\//g;
                                        my $file_handle = IO::File->new( "< $filemap" )
                                            or die "Could not open filemap '$filemap'";
                                        my $json_text = join'', $file_handle->getlines();
                                        my $json_map = decode_json( $json_text, { utf8  => 1 } );
                                        my $filelist = "/tmp/filelist.txt";
                                        my $swift_sources = join "\n", keys %$json_map;
                                        IO::File->new( "> $filelist" )->print( $swift_sources );
                                        $line =~ s/( -filelist )(\\S+)( )/$1$filelist$3/;
                                        last;
                                    }
                                }
                            }
                            # stop search
                            print $line;
                            exit 0;
                        }
                    }

                    # class/file not found
                    exit 1;
            PERL
                ) "$log" >"\(tmpfile).sh" && exit 0
            done
            exit 1;
            """) else {
            return nil
        }

        var compileCommand = try! String(contentsOfFile: "\(tmpfile).sh")
        compileCommand = compileCommand.components(separatedBy: " -o ")[0] + " "

        // remove excess escaping in new build system
        compileCommand = compileCommand
            .replacingOccurrences(of: "\\\\([\"'\\\\])", with: "$1", options: [.regularExpression])
            .replacingOccurrences(of: " -pch-output-dir \\S+ ", with: " ", options: [.regularExpression])

        // extract full path to file from compile command

        do {
            let fileExtractor = try NSRegularExpression(pattern: regexp.escaping("$"), options: [])
            guard let matches = fileExtractor.firstMatch(in: compileCommand, options: [],
                                                         range: NSMakeRange(0, compileCommand.utf16.count)),
                let sourceFile = compileCommand[matches.range(at: 1)] ??
                                 compileCommand[matches.range(at: 2)] else {
                throw evalError("Could not locate source file \(compileCommand)")
            }

            return (compileCommand, sourceFile)
        }
        catch {
            throw evalError("Regexp parse error: \(error) -- \(regexp) -- \(regexp.escaping("$"))")
        }
    }

    lazy var mainHandle = dlopen(nil, RTLD_NOLOAD)

    func injectGenerics(xcode: String, tmpfile: String, handle: UnsafeMutableRawPointer) throws {

        guard shell(command: """
            \(xcode)/Toolchains/XcodeDefault.xctoolchain/usr/bin/nm \(tmpfile).o | grep -E ' __T0.*CMn$' | awk '{print $3}' >\(tmpfile).generics
            """) else {
                throw evalError("Could not list generics symbols")
        }
        guard var generics = (try? String(contentsOfFile: "\(tmpfile).generics"))?.components(separatedBy: "\n") else {
            throw evalError("Could not load generics symbol list")
        }
        generics.removeLast()

        struct NominalTypeDescriptor {
            let Name: UInt32 = 0, NumFields: UInt32 = 0
            let FieldOffsetVectorOffset: UInt32 = 0, FieldNames: UInt32 = 0
            let GetFieldTypes: UInt32 = 0, SadnessAndKind: UInt32 = 0
        }

        struct TargetGenericMetadata {
            let CreateFunction: uintptr_t = 0, MetadataSize: UInt32 = 0
            let NumKeyArguments: UInt16 = 0, AddressPoint: UInt16 = 0

            let PrivateData1: uintptr_t = 0, PrivateData2: uintptr_t = 0
            let PrivateData3: uintptr_t = 0, PrivateData4: uintptr_t = 0
            let PrivateData5: uintptr_t = 0, PrivateData6: uintptr_t = 0
            let PrivateData7: uintptr_t = 0, PrivateData8: uintptr_t = 0
            let PrivateData9: uintptr_t = 0, PrivateData10: uintptr_t = 0
            let PrivateData11: uintptr_t = 0, PrivateData12: uintptr_t = 0
            let PrivateData13: uintptr_t = 0, PrivateData14: uintptr_t = 0
            let PrivateData15: uintptr_t = 0, PrivateData16: uintptr_t = 0

            let Destructor: uintptr_t = 0, Witness: uintptr_t = 0
            let MetaClass: uintptr_t = 0, SuperClass: uintptr_t = 0
            let CacheData1: uintptr_t = 0, CacheData2: uintptr_t = 0
            let Data: uintptr_t = 0

            let Flags: UInt32 = 0, InstanceAddressPoint: UInt32 = 0
            let InstanceSize: UInt32 = 0
            let InstanceAlignMask: UInt16 = 0, Reserved: UInt16 = 0
            let ClassSize: UInt32 = 0, ClassAddressPoint: UInt32 = 0

            var DescriptionOffset: uintptr_t = 0
        }

        func getPattern(handle: UnsafeMutableRawPointer!, sym: String) -> UnsafeMutablePointer<TargetGenericMetadata>? {
            if let desc = dlsym(handle, String(sym.dropFirst()))?
                .assumingMemoryBound(to: NominalTypeDescriptor.self),
                desc.pointee.SadnessAndKind != 0 {
                return desc.withMemoryRebound(to: UInt8.self, capacity: 1) {
                    ($0 + Int(desc.pointee.SadnessAndKind) + 5 * MemoryLayout<UInt32>.size)
                        .withMemoryRebound(to: TargetGenericMetadata.self, capacity: 1) {
                            $0
                    }
                }
            }
            return nil
        }

        for generic in generics {
            if let newpattern = getPattern(handle: handle, sym: generic),
                let oldpattern = getPattern(handle: mainHandle, sym: generic) {
                let save = oldpattern.pointee.DescriptionOffset
                memcpy(oldpattern, newpattern, Int(oldpattern.pointee.MetadataSize))
                oldpattern.pointee.DescriptionOffset = save
            }
        }
    }

    func findDerivedData(url: URL) -> URL? {
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

    func findProject(for source: URL, derivedData: URL) -> (URL, URL)? {
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

    func file(withExt ext: String, in files: [String]) -> String? {
        return files.first { URL(fileURLWithPath: $0).pathExtension == ext }
    }

    func logDir(project: URL, derivedData: URL) -> URL? {
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

    func shell(command: String) -> Bool {
        try? command.write(toFile: "/tmp/command.sh", atomically: false, encoding: .utf8)
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
@_silgen_name("execve")
func execve(_ __file: UnsafePointer<Int8>!, _ __argv: UnsafePointer<UnsafeMutablePointer<Int8>?>!, _ __envp: UnsafePointer<UnsafeMutablePointer<Int8>?>!) -> Int32
@_silgen_name("_NSGetEnviron")
func _NSGetEnviron() -> UnsafePointer<UnsafePointer<UnsafeMutablePointer<Int8>?>?>!
#endif
