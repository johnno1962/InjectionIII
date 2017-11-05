//
//  SwiftInjection.swift
//  SwiftEval
//
//  Created by John Holdsworth on 05/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/SwiftEval/SwiftInjection.swift#4 $
//
//  Cut-down version of code injection in Swift. Uses code
//  from SwiftEval.swift to recompile and reload class.
//

#if arch(x86_64) // simulator/macOS only
import Foundation

#if os(iOS)
import UIKit

extension UIViewController {

    /// inject a UIView controller and redraw
    public func injectVC() {
        inject()
        for subview in self.view.subviews {
            subview.removeFromSuperview()
        }
        if let sublayers = self.view.layer.sublayers {
            for sublayer in sublayers {
                sublayer.removeFromSuperlayer()
            }
        }
        viewDidLoad()
    }
}
#endif

extension NSObject {

    public func inject() {
        if let oldClass: AnyClass = object_getClass(self),
            let newClass = SwiftEval.rebuildClass(oldClass: oldClass, className: "\(oldClass)", extra: nil) {

            // old-school swizzle Objective-C class & instance methods
            injection(swizzle: object_getClass(newClass), onto: object_getClass(oldClass))
            injection(swizzle: newClass, onto: oldClass)

            // overwrite Swift vtable of existing class with implementations from new class
            let existingClass = unsafeBitCast(oldClass, to: UnsafeMutablePointer<ClassMetadataSwift>.self)
            let classMetadata = unsafeBitCast(newClass, to: UnsafeMutablePointer<ClassMetadataSwift>.self)

            func byteAddr<T>(_ location: UnsafeMutablePointer<T>) -> UnsafeMutablePointer<UInt8> {
                return location.withMemoryRebound(to: UInt8.self, capacity: 1) { $0 }
            }

            let vtableOffset = byteAddr(&existingClass.pointee.IVarDestroyer) - byteAddr(existingClass)
            let vtableLength = Int(existingClass.pointee.ClassSize -
                existingClass.pointee.ClassAddressPoint) - vtableOffset

            NSLog("\(unsafeBitCast(classMetadata, to: AnyClass.self)), vtable length: \(vtableLength)")
            memcpy(byteAddr(existingClass) + vtableOffset, byteAddr(classMetadata) + vtableOffset, vtableLength)

            let notification = Notification.Name("INJECTION_BUNDLE_NOTIFICATION")
            NotificationCenter.default.post(name: notification, object: [oldClass])
        }
    }

    private func injection(swizzle newClass: AnyClass?, onto oldClass: AnyClass?) {
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
#endif
