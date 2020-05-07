//
//  SwiftEval.swift
//  InjectionBundle
//
//  Created by John Holdsworth on 02/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionBundle/SwiftEval.swift#124 $
//
//  Basic implementation of a Swift "eval()" including the
//  mechanics of recompiling a class and loading the new
//  version used in the associated injection version.
//  Used as the basis of a new version of Injection.
//

#if arch(x86_64) || arch(i386) // simulator/macOS only
import Foundation

private func debug(_ str: String) {
//    print(str)
}

@objc protocol SwiftEvalImpl {
    @objc optional func evalImpl(_ptr: UnsafeMutableRawPointer)
}

extension NSObject {

    private static var lastEvalByClass = [String: String]()

    @objc public func evalSwift(_ expression: String) {
        eval("{\n\(expression)\n}", (() -> ())?.self)?()
    }

    /// eval() for String value
    public func eval(_ expression: String) -> String {
        return eval("\"\(expression)\"", String.self)
    }

    /// eval() for value of any type
    public func eval<T>(_ expression: String, _ type: T.Type) -> T {
        let oldClass: AnyClass = object_getClass(self)!
        let className = "\(oldClass)"
        let extra = """

            extension \(className) {

                @objc func evalImpl(_ptr: UnsafeMutableRawPointer) {
                    func xprint<T>(_ str: T) {
                        if let xprobe = NSClassFromString("Xprobe") {
                            #if swift(>=4.0)
                            _ = (xprobe as AnyObject).perform(Selector(("xlog:")), with: "\\(str)")
                            #elseif swift(>=3.0)
                            Thread.detachNewThreadSelector(Selector(("xlog:")), toTarget:xprobe, with:"\\(str)" as NSString)
                            #else
                            NSThread.detachNewThreadSelector(Selector("xlog:"), toTarget:xprobe, withObject:"\\(str)" as NSString)
                            #endif
                        }
                    }

                    #if swift(>=3.0)
                    struct XprobeOutputStream: TextOutputStream {
                        var out = ""
                        mutating func write(_ string: String) {
                            out += string
                        }
                    }

                    func xdump<T>(_ arg: T) {
                        var stream = XprobeOutputStream()
                        dump(arg, to: &stream)
                        xprint(stream.out)
                    }
                    #endif

                    let _ptr = _ptr.assumingMemoryBound(to: (\(type)).self)
                    _ptr.pointee = \(expression)
                }
            }

            """

        // update evalImpl to implement expression

        if NSObject.lastEvalByClass[className] != expression {
            do {
                let tmpfile = try SwiftEval.instance.rebuildClass(oldClass: oldClass, classNameOrFile: className, extra: extra)
                if let newClass = try SwiftEval.instance.loadAndInject(tmpfile: tmpfile, oldClass: oldClass).first {
                    if NSStringFromClass(newClass) != NSStringFromClass(oldClass) {
                        NSLog("Class names different. Have the right class been loaded?")
                    }

                    // swizzle new version of evalImpl onto class

                    let selector = #selector(SwiftEvalImpl.evalImpl(_ptr:))
                    if let newMethod = class_getInstanceMethod(newClass, selector) {
                        class_replaceMethod(oldClass, selector,
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
            unsafeBitCast(self, to: SwiftEvalImpl.self).evalImpl?(_ptr: ptr)
        }
        let out = ptr.pointee
        ptr.deallocate()
        return out
    }
}

fileprivate extension String {
    subscript(range: NSRange) -> String? {
        return Range(range, in: self).flatMap { String(self[$0]) }
    }
    func escaping(_ chars: String, with template: String = "\\$0") -> String {
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
    @objc public var vaccineEnabled: Bool = false

    // client specific info
    @objc public var frameworks = Bundle.main.privateFrameworksPath
                                    ?? Bundle.main.bundlePath + "/Frameworks"
    @objc public var arch = "x86_64"

    // Xcode related info
    @objc public var xcodeDev = "/Applications/Xcode.app/Contents/Developer"

    @objc public var projectFile: String?
    @objc public var derivedLogs: String?
    @objc public var tmpDir = "/tmp" {
        didSet {
//            SwiftEval.buildCacheFile = "\(tmpDir)/eval_builds.plist"
        }
    }

    /// Error handler
    @objc public var evalError = {
        (_ message: String) -> Error in
        print("💉 *** \(message) ***")
        return NSError(domain: "SwiftEval", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    @objc public var injectionNumber = 0
    @objc public var lastIdeProcPath = ""

    static var compileByClass = [String: (String, String)]()

    static var buildCacheFile = "/tmp/eval_builds.plist"
    static var longTermCache = NSMutableDictionary(contentsOfFile: buildCacheFile) ?? NSMutableDictionary()

    public func determineEnvironment(classNameOrFile: String) throws -> (URL, URL) {
        // Largely obsolete section used find Xcode paths from source file being injected.

        let sourceURL = URL(fileURLWithPath: classNameOrFile.hasPrefix("/") ? classNameOrFile : #file)
        guard let derivedData = findDerivedData(url: URL(fileURLWithPath: NSHomeDirectory()), ideProcPath: self.lastIdeProcPath) ??
            (self.projectFile != nil ?
                findDerivedData(url: URL(fileURLWithPath: self.projectFile!), ideProcPath: self.lastIdeProcPath) :
                findDerivedData(url: sourceURL, ideProcPath: self.lastIdeProcPath)) else {
                throw evalError("Could not locate derived data. Is the project under your home directory?")
        }
        guard let (projectFile, logsDir) =
            self.derivedLogs
                .flatMap({ (URL(fileURLWithPath: self.projectFile!), URL(fileURLWithPath: $0)) }) ??
                self.projectFile
                    .flatMap({ logsDir(project: URL(fileURLWithPath: $0), derivedData: derivedData) })
                    .flatMap({ (URL(fileURLWithPath: self.projectFile!), $0) }) ??
                findProject(for: sourceURL, derivedData: derivedData) else {
                    throw evalError("""
                        Could not locate containing project or it's logs.
                        For a macOS app you need to turn off the App Sandbox.
                        Have you customised the DerivedData path?
                        """)
        }

        return (projectFile, logsDir)
    }

    @objc public func rebuild(storyboard: String) throws {
        let (_, logsDir) = try determineEnvironment(classNameOrFile: storyboard)

        injectionNumber += 1
        let tmpfile = "\(tmpDir)/eval\(injectionNumber)"
        let logfile = "\(tmpfile).log"

        // messy but fast
        guard shell(command: """
            # search through build logs, most recent first
            for log in `ls -t "\(logsDir.path)/"*.xcactivitylog`; do
                #echo "Scanning $log"
                /usr/bin/env perl <(cat <<'PERL'
                    use English;
                    use strict;

                    # line separator in Xcode logs
                    $INPUT_RECORD_SEPARATOR = "\\r";

                    # format is gzip
                    open GUNZIP, "/usr/bin/gunzip <\\"$ARGV[0]\\" 2>/dev/null |" or die;

                    # grep the log until to find codesigning for product path
                    my $realPath;
                    while (defined (my $line = <GUNZIP>)) {
                        if ($line =~ /^\\s*cd /) {
                            $realPath = $line;
                        }
                        elsif (my ($product) = $line =~ m@/usr/bin/ibtool.*? --link (\\S+\\.app)@o) {
                            print $product;
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
            throw evalError("Could not locate storyboard compile")
        }

        let resources = try! String(contentsOfFile: "\(tmpfile).sh")
                            .trimmingCharacters(in: .whitespaces)

        guard shell(command: """
            (cd "\(resources)" && for i in 1 2 3 4 5; do if (find . -name '*.nib' -a -newer "\(storyboard)" | grep .nib >/dev/null); then break; fi; sleep 1; done; while (ps auxww | grep -v grep | grep "/ibtool " >/dev/null); do sleep 1; done; for i in `find . -name '*.nib'`; do cp -rf "$i" "\(Bundle.main.bundlePath)/$i"; done >\(logfile) 2>&1)
            """) else {
                throw evalError("Re-compilation failed (\(tmpDir)/command.sh)\n\(try! String(contentsOfFile: logfile))")
        }

        _ = evalError("Copied \(storyboard)")
    }

    @objc public func rebuildClass(oldClass: AnyClass?, classNameOrFile: String, extra: String?) throws -> String {
        let (projectFile, logsDir) = try determineEnvironment(classNameOrFile: classNameOrFile)

        // locate compile command for class

        injectionNumber += 1
        let tmpfile = "\(tmpDir)/eval\(injectionNumber)"
        let logfile = "\(tmpfile).log"

        guard let (compileCommand, sourceFile) = try SwiftEval.compileByClass[classNameOrFile] ??
            findCompileCommand(logsDir: logsDir, classNameOrFile: classNameOrFile, tmpfile: tmpfile) ??
            SwiftEval.longTermCache[classNameOrFile].flatMap({ ($0 as! String, classNameOrFile) }) else {
            throw evalError("""
                Could not locate compile command for \(classNameOrFile)
                (Injection does not work with Whole Module Optimization.
                There are also restrictions on characters allowed in paths.
                All paths are also case sensitive is another thing to check.)
                """)
        }

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

        _ = evalError("Compiling \(sourceFile)")

        guard shell(command: """
                (cd "\(projectDir.escaping("$"))" && \(compileCommand) -o \(tmpfile).o >\(logfile) 2>&1)
                """) else {
            SwiftEval.compileByClass.removeValue(forKey: classNameOrFile)
            throw evalError("Re-compilation failed (\(tmpDir)/command.sh)\n\(try! String(contentsOfFile: logfile))")
        }

        SwiftEval.compileByClass[classNameOrFile] = (compileCommand, sourceFile)
        if SwiftEval.longTermCache[classNameOrFile] as? String != compileCommand && classNameOrFile.hasPrefix("/") {
            SwiftEval.longTermCache[classNameOrFile] = compileCommand
            SwiftEval.longTermCache.write(toFile: SwiftEval.buildCacheFile, atomically: false)
        }

        // link resulting object file to create dynamic library

        let toolchain = ((try! NSRegularExpression(pattern: "\\s*(\\S+?\\.xctoolchain)", options: []))
            .firstMatch(in: compileCommand, options: [], range: NSMakeRange(0, compileCommand.utf16.count))?
            .range(at: 1)).flatMap { compileCommand[$0] } ?? "\(xcodeDev)/Toolchains/XcodeDefault.xctoolchain"

        let osSpecific: String
        if compileCommand.contains("iPhoneSimulator.platform") {
            osSpecific = "-isysroot \(xcodeDev)/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk -mios-simulator-version-min=9.0 -L\(toolchain)/usr/lib/swift/iphonesimulator -undefined dynamic_lookup"// -Xlinker -bundle_loader -Xlinker \"\(Bundle.main.executablePath!)\""
        } else if compileCommand.contains("AppleTVSimulator.platform") {
            osSpecific = "-isysroot \(xcodeDev)/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk -mtvos-simulator-version-min=9.0 -L\(toolchain)/usr/lib/swift/appletvsimulator -undefined dynamic_lookup"// -Xlinker -bundle_loader -Xlinker \"\(Bundle.main.executablePath!)\""
        } else {
            osSpecific = "-isysroot \(xcodeDev)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -mmacosx-version-min=10.11 -L\(toolchain)/usr/lib/swift/macosx -undefined dynamic_lookup"
        }

        guard shell(command: """
            \(xcodeDev)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -arch "\(arch)" -bundle \(osSpecific) -dead_strip -Xlinker -objc_abi_version -Xlinker 2 -fobjc-arc \(tmpfile).o -L "\(frameworks)" -F "\(frameworks)" -rpath "\(frameworks)" -o \(tmpfile).dylib >>\(logfile) 2>&1
            """) else {
            throw evalError("Link failed, check \(tmpDir)/command.sh\n\(try! String(contentsOfFile: logfile))")
        }

        // codesign dylib

        if signer != nil {
            guard signer!("\(tmpfile).dylib") else {
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
                export CODESIGN_ALLOCATE=\(xcodeDev)/Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate; codesign --force -s '-' "\(tmpfile).dylib"
                """) else {
                throw evalError("Codesign failed")
            }
            #endif
        }

        // Reset dylib to prevent macOS 10.15 from blocking it
        let url = URL(fileURLWithPath: "\(tmpfile).dylib")
        let dylib = try Data(contentsOf: url)
        try filemgr.removeItem(at: url)
        try dylib.write(to: url)

        return tmpfile
    }

    @objc func loadAndInject(tmpfile: String, oldClass: AnyClass? = nil) throws -> [AnyClass] {

        print("💉 Loading .dylib ...")
        // load patched .dylib into process with new version of class
        guard let dl = dlopen("\(tmpfile).dylib", RTLD_NOW) else {
            let error = String(cString: dlerror())
            if error.contains("___llvm_profile_runtime") {
                print("💉 Loading .dylib has failed, try turning off collection of test coverage in your scheme")
            }
            throw evalError("dlopen() error: \(error)")
        }
        print("💉 Loaded .dylib - Ignore any duplicate class warning ^")

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

            let classSymbolNames = try extractClasSymbols(tmpfile: tmpfile)

            return Set(classSymbolNames.compactMap {
                dlsym(dl, String($0.dropFirst())) })
                .map { unsafeBitCast($0, to: AnyClass.self) }
        }
    }

    func extractClasSymbols(tmpfile: String) throws -> [String] {

        guard shell(command: """
            \(xcodeDev)/Toolchains/XcodeDefault.xctoolchain/usr/bin/nm \(tmpfile).o | grep -E ' S _OBJC_CLASS_\\$_| _(_T0|\\$S|\\$s).*CN$' | awk '{print $3}' >\(tmpfile).classes
            """) else {
            throw evalError("Could not list class symbols")
        }
        guard var symbols = (try? String(contentsOfFile: "\(tmpfile).classes"))?.components(separatedBy: "\n") else {
            throw evalError("Could not load class symbol list")
        }
        symbols.removeLast()

        return symbols
    }

    func findCompileCommand(logsDir: URL, classNameOrFile: String, tmpfile: String) throws -> (compileCommand: String, sourceFile: String)? {
        // path to project can contain spaces and '$&(){}
        // Objective-C paths can only contain space and '
        // project file itself can only contain spaces
        let isFile = classNameOrFile.hasPrefix("/")
        if isFile && (try? String(contentsOfFile: classNameOrFile)) == nil {
            throw evalError("""
                File \(classNameOrFile) is not readable. This could be because
                the file is in a secure area of the file system or because the
                case of the letters in the file name does not match that in the
                Xcode project. The file system injection uses is case sensitive.
                """)
        }

        let sourceRegex = isFile ? "\\Q\(classNameOrFile)\\E" : "/\(classNameOrFile)\\.(?:swift|mm?)"
        let swiftEscaped = (isFile ? "" : "[^\"]*?") + sourceRegex.escaping("'$", with: "\\E\\\\*$0\\Q")
        let objcEscaped = (isFile ? "" : "\\S*?") + sourceRegex.escaping("' ")
        var regexp = " -(?:primary-file|c(?<! -frontend -c)) (?:\\\\?\"(\(swiftEscaped))\\\\?\"|(\(objcEscaped))) "

        // messy but fast
        guard shell(command: """
            # search through build logs, most recent first
            for log in `ls -t "\(logsDir.path)/"*.xcactivitylog`; do
                #echo "Scanning $log"
                /usr/bin/env perl <(cat <<'PERL'
                    use JSON::PP;
                    use English;
                    use strict;

                    # line separator in Xcode logs
                    $INPUT_RECORD_SEPARATOR = "\\r";

                    # format is gzip
                    open GUNZIP, "/usr/bin/gunzip <\\"$ARGV[0]\\" 2>/dev/null |" or die;

                    # grep the log until there is a match
                    my $realPath;
                    while (defined (my $line = <GUNZIP>)) {
                        if ($line =~ /^\\s*cd /) {
                            $realPath = $line;
                        }
                        elsif ($line =~ m@\(regexp.escaping("\"$"))@o and $line =~ " \(arch)") {
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
                                        my $filelist = "\(tmpDir)/filelist.txt";
                                        my $swift_sources = join "\n", keys %$json_map;
                                        my $listfile = IO::File->new( "> $filelist" )
                                            or die "Could not open list file '$filelist'";
                                        binmode $listfile, ':utf8';
                                        $listfile->print( $swift_sources );
                                        $listfile->close();
                                        $line =~ s/( -filelist )(\\S+)( )/$1$filelist$3/;
                                        last;
                                    }
                                }
                            }
                            if ($realPath and (undef, $realPath) = $realPath =~ /cd (\\"?)(.*?)\\1\\r/) {
            #                                print "cd \\"$realPath\\" && ";
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
//            // escape ( & ) outside quotes
//            .replacingOccurrences(of: "[()](?=(?:(?:[^\"]*\"){2})*[^\"]$)", with: "\\\\$0", options: [.regularExpression])
            // (logs of new build system escape ', $ and ")
            .replacingOccurrences(of: "\\\\([\"'\\\\])", with: "$1", options: [.regularExpression])
            // pch file may no longer exist
            .replacingOccurrences(of: " -pch-output-dir \\S+ ", with: " ", options: [.regularExpression])

        if isFile {
            return (compileCommand, classNameOrFile)
        }

        // for eval() extract full path to file from compile command

        let fileExtractor: NSRegularExpression
        regexp = regexp.escaping("$")

        do {
            fileExtractor = try NSRegularExpression(pattern: regexp, options: [])
        }
        catch {
            throw evalError("Regexp parse error: \(error) -- \(regexp)")
        }

        guard let matches = fileExtractor.firstMatch(in: compileCommand, options: [],
                                                     range: NSMakeRange(0, compileCommand.utf16.count)),
            let sourceFile = compileCommand[matches.range(at: 1)] ??
                             compileCommand[matches.range(at: 2)] else {
            throw evalError("Could not locate source file \(compileCommand) -- \(regexp)")
        }

        return (compileCommand, sourceFile.replacingOccurrences(of: "\\$", with: "$"))
    }

    func getAppCodeDerivedData(procPath: String) -> String {
        //Default with current year
        let derivedDataPath = { (year: Int, pathSelector: String) -> String in
            "Library/Caches/\(year > 2019 ? "JetBrains/" : "")\(pathSelector)/DerivedData"
        }

        let year = Calendar.current.component(.year, from: Date())
        let month = Calendar.current.component(.month, from: Date())

        let defaultPath = derivedDataPath(year, "AppCode\(month / 4 == 0 ? year - 1 : year).\(month / 4 + (month / 4 == 0 ? 3 : 0))")

        var plistPath = URL(fileURLWithPath: procPath)
        plistPath.deleteLastPathComponent()
        plistPath.deleteLastPathComponent()
        plistPath = plistPath.appendingPathComponent("Info.plist")

        guard let dictionary = NSDictionary(contentsOf: plistPath) as? Dictionary<String, Any> else { return defaultPath }
        guard let jvmOptions = dictionary["JVMOptions"] as? Dictionary<String, Any> else { return defaultPath }
        guard let properties = jvmOptions["Properties"] as? Dictionary<String, Any> else { return defaultPath }
        guard let pathSelector: String = properties["idea.paths.selector"] as? String else { return defaultPath }

        let components = pathSelector.replacingOccurrences(of: "AppCode", with: "").components(separatedBy: ".")
        guard components.count == 2 else { return defaultPath }

        guard let realYear = Int(components[0]) else { return defaultPath }
        return derivedDataPath(realYear, pathSelector)
    }

    func findDerivedData(url: URL, ideProcPath: String) -> URL? {
        if url.path == "/" {
            return nil
        }

        var relativeDirs = ["DerivedData", "build/DerivedData"]
        if ideProcPath.lowercased().contains("appcode") {
            relativeDirs.append(getAppCodeDerivedData(procPath: ideProcPath))
        } else {
            relativeDirs.append("Library/Developer/Xcode/DerivedData")
        }
        for relative in relativeDirs {
            let derived = url.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: derived.path) {
                return derived
            }
        }

        return findDerivedData(url: url.deletingLastPathComponent(), ideProcPath: ideProcPath)
    }

    func findProject(for source: URL, derivedData: URL) -> (projectFile: URL, logsDir: URL)? {
        let dir = source.deletingLastPathComponent()
        if dir.path == "/" {
            return nil
        }

        var candidate = findProject(for: dir, derivedData: derivedData)

        if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path),
            let project = file(withExt: "xcworkspace", in: files) ?? file(withExt: "xcodeproj", in: files),
            let logsDir = logsDir(project: dir.appendingPathComponent(project), derivedData: derivedData),
            mtime(logsDir) > candidate.flatMap({ mtime($0.logsDir) }) ?? 0 {
                candidate = (dir.appendingPathComponent(project), logsDir)
        }

        return candidate
    }

    func file(withExt ext: String, in files: [String]) -> String? {
        return files.first { URL(fileURLWithPath: $0).pathExtension == ext }
    }

    func mtime(_ url: URL) -> time_t {
        var info = stat()
        return stat(url.path, &info) == 0 ? info.st_mtimespec.tv_sec : 0
    }

    func logsDir(project: URL, derivedData: URL) -> URL? {
        let filemgr = FileManager.default
        let projectPrefix = project.deletingPathExtension()
            .lastPathComponent.replacingOccurrences(of: "\\s+", with: "_",
                                    options: .regularExpression, range: nil)
        let relativeDerivedData = derivedData
            .appendingPathComponent("\(projectPrefix)/Logs/Build")

        return ((try? filemgr.contentsOfDirectory(atPath: derivedData.path))?
            .filter { $0.starts(with: projectPrefix + "-") }
            .map { derivedData.appendingPathComponent($0 + "/Logs/Build") }
            ?? [] + [relativeDerivedData])
            .filter { filemgr.fileExists(atPath: $0.path) }
            .sorted { mtime($0) > mtime($1) }
            .first
    }

    func shell(command: String) -> Bool {
        let commandFile = "\(tmpDir)/command.sh"
        try! command.write(toFile: commandFile, atomically: false, encoding: .utf8)
        debug(command)

        #if os(iOS) || os(tvOS)
        return runner.run(script: commandFile)
        #else
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus == EXIT_SUCCESS
        #endif
    }

    #if os(iOS) || os(tvOS)
    let runner = ScriptRunner()
    #endif
}

#if os(iOS) || os(tvOS)
class ScriptRunner {
    let commandsOut: UnsafeMutablePointer<FILE>
    let statusesIn: UnsafeMutablePointer<FILE>

    init() {
        let ForReading = 0, ForWriting = 1
        var commandsPipe = [Int32](repeating: 0, count: 2)
        var statusesPipe = [Int32](repeating: 0, count: 2)
        pipe(&commandsPipe)
        pipe(&statusesPipe)

        if fork() == 0 {
            let commandsIn = fdopen(commandsPipe[ForReading], "r")
            let statusesOut = fdopen(statusesPipe[ForWriting], "w")
            var buffer = [Int8](repeating: 0, count: 4096)

            close(commandsPipe[ForWriting])
            close(statusesPipe[ForReading])
            setbuf(statusesOut, nil)

            while let script = fgets(&buffer, Int32(buffer.count), commandsIn) {
                script[strlen(script)-1] = 0

                let pid = fork()
                if pid == 0 {
                    var argv = [UnsafeMutablePointer<Int8>?](repeating: nil, count: 3)
                    argv[0] = strdup("/bin/bash")!
                    argv[1] = strdup(script)!
                    _ = execve(argv[0], &argv, nil)
                    fatalError("execve() fails \(String(cString: strerror(errno)))")
                }

                var status: Int32 = 0
                while waitpid(pid, &status, 0) == -1 {}
                fputs("\(status >> 8)\n", statusesOut)
            }

            exit(0)
        }

        commandsOut = fdopen(commandsPipe[ForWriting], "w")
        statusesIn = fdopen(statusesPipe[ForReading], "r")

        close(commandsPipe[ForReading])
        close(statusesPipe[ForWriting])
        setbuf(commandsOut, nil)
    }

    func run(script: String) -> Bool {
        fputs("\(script)\n", commandsOut)
        var buffer = [Int8](repeating: 0, count: 10)
        fgets(&buffer, Int32(buffer.count), statusesIn)
        return buffer[0] == "0".utf8.first!
    }
}

@_silgen_name("fork")
func fork() -> Int32
@_silgen_name("execve")
func execve(_ __file: UnsafePointer<Int8>!, _ __argv: UnsafePointer<UnsafeMutablePointer<Int8>?>!, _ __envp: UnsafePointer<UnsafeMutablePointer<Int8>?>!) -> Int32
#endif
#endif
