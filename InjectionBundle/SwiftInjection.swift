//
//  SwiftInjection.swift
//  InjectionBundle
//
//  Created by John Holdsworth on 05/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionBundle/SwiftInjection.swift#48 $
//
//  Cut-down version of code injection in Swift. Uses code
//  from SwiftEval.swift to recompile and reload class.
//

import Foundation

private let debugSweep = getenv("DEBUG_SWEEP") != nil

@objc public protocol SwiftInjected {
    @objc optional func injected()
}


@objc
public class SwiftInjection: NSObject {
    
    // Functions just implemented if they are going to use XCTest framework
    func appendTestClass(_ newClass: AnyClass) {}
    func proceedTestClasses() {}
    
    @objc
    public func inject(oldClass: AnyClass?, classNameOrFile: String) {
        do {
            let tmpfile = try SwiftEval.instance.rebuildClass(oldClass: oldClass,
                                    classNameOrFile: classNameOrFile, extra: nil)
            try inject(tmpfile: tmpfile)
        }
        catch {
        }
    }
    
    @objc
    public func inject(tmpfile: String) throws {
        let newClasses = try SwiftEval.instance.loadAndInject(tmpfile: tmpfile)
        let oldClasses = //oldClass != nil ? [oldClass!] :
            newClasses.map { objc_getClass(class_getName($0)) as! AnyClass }
        var testClasses = [AnyClass]()
        for i in 0..<oldClasses.count {
            let oldClass: AnyClass = oldClasses[i], newClass: AnyClass = newClasses[i]

            // old-school swizzle Objective-C class & instance methods
            injection(swizzle: object_getClass(newClass), onto: object_getClass(oldClass))
            injection(swizzle: newClass, onto: oldClass)

            // overwrite Swift vtable of existing class with implementations from new class
            let existingClass = unsafeBitCast(oldClass, to: UnsafeMutablePointer<ClassMetadataSwift>.self)
            let classMetadata = unsafeBitCast(newClass, to: UnsafeMutablePointer<ClassMetadataSwift>.self)

            // Is this a Swift class?
            // Reference: https://github.com/apple/swift/blob/master/include/swift/ABI/Metadata.h#L1195
            let oldSwiftCondition = classMetadata.pointee.Data & 0x1 == 1
            let newSwiftCondition = classMetadata.pointee.Data & 0x3 != 0
            let isSwiftClass = newSwiftCondition || oldSwiftCondition
            if isSwiftClass {
              // Swift equivalent of Swizzling
                if classMetadata.pointee.ClassSize != existingClass.pointee.ClassSize {
                    print("💉 ⚠️ Adding or removing methods on Swift classes is not supported. Your application will likely crash. ⚠️")
                }

                func byteAddr<T>(_ location: UnsafeMutablePointer<T>) -> UnsafeMutablePointer<UInt8> {
                    return location.withMemoryRebound(to: UInt8.self, capacity: 1) { $0 }
                }

                let vtableOffset = byteAddr(&existingClass.pointee.IVarDestroyer) - byteAddr(existingClass)
                let vtableLength = Int(existingClass.pointee.ClassSize -
                    existingClass.pointee.ClassAddressPoint) - vtableOffset

                print("💉 Injected '\(oldClass)'")
                memcpy(byteAddr(existingClass) + vtableOffset,
                       byteAddr(classMetadata) + vtableOffset, vtableLength)
            }

            appendTestClass(newClass)
        }
        
        proceedTestClasses()
        
        var injectedClasses = [AnyClass]()
        for cls in oldClasses {
            if class_getInstanceMethod(cls, #selector(SwiftInjected.injected)) != nil {
                injectedClasses.append(cls)
                let kvoName = "NSKVONotifying_" + NSStringFromClass(cls)
                if let kvoCls = NSClassFromString(kvoName) {
                    injectedClasses.append(kvoCls)
                }
            }
        }

        // implement -injected() method using sweep of objects in application
        if !injectedClasses.isEmpty {
            #if os(iOS) || os(tvOS)
            let app = UIApplication.shared
            #else
            let app = NSApplication.shared
            #endif
            let seeds: [Any] =  [app.delegate as Any] + app.windows
            SwiftSweeper(instanceTask: {
                (instance: AnyObject) in
                if injectedClasses.contains(where: { $0 == object_getClass(instance) }) {
                    let proto = unsafeBitCast(instance, to: SwiftInjected.self)
                    if SwiftEval.sharedInstance().vaccineEnabled {
                        self.performVaccineInjection(instance)
                        proto.injected?()
                        return
                    }

                    proto.injected?()

                    #if os(iOS) || os(tvOS)
                    if let vc = instance as? UIViewController {
                        vc.flashToUpdate()
                    }
                    #endif
                }
            }).sweepValue(seeds)
        }
        
        let notification = Notification.Name("INJECTION_BUNDLE_NOTIFICATION")
        NotificationCenter.default.post(name: notification, object: oldClasses)
    }

    @objc(vaccine:)
    public func performVaccineInjection(_ object: AnyObject) {
        let vaccine = Vaccine()
        vaccine.performInjection(on: object)
    }

    func injection(swizzle newClass: AnyClass?, onto oldClass: AnyClass?) {
        var methodCount: UInt32 = 0
        if let methods = class_copyMethodList(newClass, &methodCount) {
            for i in 0 ..< Int(methodCount) {
                class_replaceMethod(oldClass, method_getName(methods[i]),
                                    method_getImplementation(methods[i]),
                                    method_getTypeEncoding(methods[i]))
            }
            free(methods)
        }
    }
}

class SwiftSweeper {

    static var current: SwiftSweeper?

    let instanceTask: (AnyObject) -> Void
    var seen = [UnsafeRawPointer: Bool]()

    init(instanceTask: @escaping (AnyObject) -> Void) {
        self.instanceTask = instanceTask
        SwiftSweeper.current = self
    }

    func sweepValue(_ value: Any) {
        let mirror = Mirror(reflecting: value)
        if var style = mirror.displayStyle {
            if _typeName(mirror.subjectType).hasPrefix("Swift.ImplicitlyUnwrappedOptional<") {
                style = .optional
            }
            switch style {
            case .set, .collection:
                for (_, child) in mirror.children {
                    sweepValue(child)
                }
                return
            case .dictionary:
                for (_, child) in mirror.children {
                    for (_, element) in Mirror(reflecting: child).children {
                        sweepValue(element)
                    }
                }
                return
            case .class:
                sweepInstance(value as AnyObject)
                return
            case .optional, .enum:
                if let evals = mirror.children.first?.value {
                    sweepValue(evals)
                }
            case .tuple, .struct:
                sweepMembers(value)
            }
        }
    }

    func sweepInstance(_ instance: AnyObject) {
        let reference = unsafeBitCast(instance, to: UnsafeRawPointer.self)
        if seen[reference] == nil {
            seen[reference] = true
            if debugSweep {
                print("Sweeping instance \(reference) of class \(type(of: instance))")
            }

            instanceTask(instance)

            sweepMembers(instance)
            instance.legacySwiftSweep?()
        }
    }

    func sweepMembers(_ instance: Any) {
        var mirror: Mirror? = Mirror(reflecting: instance)
        while mirror != nil {
            for (_, value) in mirror!.children {
                sweepValue(value)
            }
            mirror = mirror!.superclassMirror
        }
    }
}

extension NSObject {
    @objc func legacySwiftSweep() {
        var icnt: UInt32 = 0, cls: AnyClass? = object_getClass(self)!
        let object = "@".utf16.first!
        while cls != nil && cls != NSObject.self && cls != NSURL.self {
            let className = NSStringFromClass(cls!)
            if className.hasPrefix("_") {
                return
            }
            #if os(OSX)
            if className.starts(with: "NS") && cls != NSWindow.self {
                return
            }
            #endif
            if let ivars = class_copyIvarList(cls, &icnt) {
                for i in 0 ..< Int(icnt) {
                    if let type = ivar_getTypeEncoding(ivars[i]), type[0] == object {
                        (unsafeBitCast(self, to: UnsafePointer<Int8>.self) + ivar_getOffset(ivars[i]))
                            .withMemoryRebound(to: AnyObject?.self, capacity: 1) {
//                                print("\(self) \(String(cString: ivar_getName(ivars[i])!))")
                                if let obj = $0.pointee {
                                    SwiftSweeper.current?.sweepInstance(obj)
                                }
                        }
                    }
                }
                free(ivars)
            }
            cls = class_getSuperclass(cls)
        }
    }
}

extension NSSet {
    @objc override func legacySwiftSweep() {
        self.forEach { SwiftSweeper.current?.sweepInstance($0 as AnyObject) }
    }
}

extension NSArray {
    @objc override func legacySwiftSweep() {
        self.forEach { SwiftSweeper.current?.sweepInstance($0 as AnyObject) }
    }
}

extension NSDictionary {
    @objc override func legacySwiftSweep() {
        self.allValues.forEach { SwiftSweeper.current?.sweepInstance($0 as AnyObject) }
    }
}

/**
 Layout of a class instance. Needs to be kept in sync with ~swift/include/swift/Runtime/Metadata.h
 */
public struct ClassMetadataSwift {

    public let MetaClass: uintptr_t = 0, SuperClass: uintptr_t = 0
    public let CacheData1: uintptr_t = 0, CacheData2: uintptr_t = 0

    public let Data: uintptr_t = 0

    /// Swift-specific class flags.
    public let Flags: UInt32 = 0

    /// The address point of instances of this type.
    public let InstanceAddressPoint: UInt32 = 0

    /// The required size of instances of this type.
    /// 'InstanceAddressPoint' bytes go before the address point;
    /// 'InstanceSize - InstanceAddressPoint' bytes go after it.
    public let InstanceSize: UInt32 = 0

    /// The alignment mask of the address point of instances of this type.
    public let InstanceAlignMask: UInt16 = 0

    /// Reserved for runtime use.
    public let Reserved: UInt16 = 0

    /// The total size of the class object, including prefix and suffix
    /// extents.
    public let ClassSize: UInt32 = 0

    /// The offset of the address point within the class object.
    public let ClassAddressPoint: UInt32 = 0

    /// An out-of-line Swift-specific description of the type, or null
    /// if this is an artificial subclass.  We currently provide no
    /// supported mechanism for making a non-artificial subclass
    /// dynamically.
    public let Description: uintptr_t = 0

    /// A function for destroying instance variables, used to clean up
    /// after an early return from a constructor.
    public var IVarDestroyer: SIMP? = nil

    // After this come the class members, laid out as follows:
    //   - class members for the superclass (recursively)
    //   - metadata reference for the parent, if applicable
    //   - generic parameters for this class
    //   - class variables (if we choose to support these)
    //   - "tabulated" virtual methods

}

/** pointer to a function implementing a Swift method */
public typealias SIMP = @convention(c) (_: AnyObject) -> Void

#if swift(>=3.0)
// not public in Swift3
@_silgen_name("swift_demangle")
private
func _stdlib_demangleImpl(
    mangledName: UnsafePointer<CChar>?,
    mangledNameLength: UInt,
    outputBuffer: UnsafeMutablePointer<UInt8>?,
    outputBufferSize: UnsafeMutablePointer<UInt>?,
    flags: UInt32
    ) -> UnsafeMutablePointer<CChar>?

public func _stdlib_demangleName(_ mangledName: String) -> String {
    return mangledName.utf8CString.withUnsafeBufferPointer {
        (mangledNameUTF8) in

        let demangledNamePtr = _stdlib_demangleImpl(
            mangledName: mangledNameUTF8.baseAddress,
            mangledNameLength: UInt(mangledNameUTF8.count - 1),
            outputBuffer: nil,
            outputBufferSize: nil,
            flags: 0)

        if let demangledNamePtr = demangledNamePtr {
            let demangledName = String(cString: demangledNamePtr)
            free(demangledNamePtr)
            return demangledName
        }
        return mangledName
    }
}
#endif
