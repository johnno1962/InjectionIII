//
//  SwiftUISupport.swift
//  SwiftUISupport
//
//  Created by John Holdsworth on 25/09/2020.
//  Copyright © 2020 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/SwiftUISupport/SwiftUISupport.swift#25 $
//

import SwiftUI
import SwiftTrace

/// Add conformances for types that contain floats
extension SwiftUI.EdgeInsets: SwiftTraceFloatArg {}
extension SwiftUI.UnitPoint: SwiftTraceFloatArg {}
extension SwiftUI.Angle: SwiftTraceFloatArg {}
    
/// generic function to find the Binding type for a wrapped type
public func getBindingType<Type>(value: Type, out: inout Any.Type?) {
    if !SwiftMeta.structsPassedByReference.contains(autoBitCast(Type.self)) {
        out = SwiftUI.Binding<Type>.self
    }
}

/// generic function to find the Binding type for a wrapped type
public func getStateType<Type>(value: Type, out: inout Any.Type?) {
    out = SwiftUI.State<Type>.self
}

@objc (SwiftUISupport)
class SwiftUISupport: NSObject {

    @objc class func setup(pointer: UnsafeMutableRawPointer?) {
        if let swiftUIPath = swiftUIBundlePath() {
            _ = SwiftMeta.structsPassedByReference
            SwiftMeta.process(bundlePath: swiftUIPath,
                              problemTypes: &SwiftMeta.structsPassedByReference)
        }
        SwiftMeta.wrapperHandlers["SwiftUI.Binding<"] =
            SwiftMeta.bindGeneric(name: "getBindingType", owner: Self.self)
        SwiftMeta.wrapperHandlers["SwiftUI.State<"] =
            SwiftMeta.bindGeneric(name: "getStateType", owner: Self.self)
        SwiftTrace.makeTraceable(types: [SwiftUI.Text.self])
        print("💉 Installed SwiftUI type handlers")
    }
}
