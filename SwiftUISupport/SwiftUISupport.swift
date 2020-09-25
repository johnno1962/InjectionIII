//
//  SwiftUISupport.swift
//  SwiftUISupport
//
//  Created by John Holdsworth on 25/09/2020.
//  Copyright © 2020 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/SwiftUISupport/SwiftUISupport.swift#4 $
//

import SwiftUI

extension SwiftUI.EdgeInsets: SwiftTraceFloatArg {}

@objc (SwiftUISupport)
class SwiftUISupport: NSObject {

    @objc class func setup(pointer: UnsafeMutableRawPointer) {
        let swiftTypeHandlers = pointer.assumingMemoryBound(to:
            [String: (SwiftTrace.Swizzle.Invocation, Bool) -> String?].self)
        
        print("💉 Installed SwiftUI type handlers")
        swiftTypeHandlers.pointee["SwiftUI.Text"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.Text.self) }
        swiftTypeHandlers.pointee["SwiftUI.Color"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.Color.self) }
        swiftTypeHandlers.pointee["SwiftUI.Edge.Set"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.Edge.Set.self) }
        swiftTypeHandlers.pointee["SwiftUI.EdgeInsets"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.EdgeInsets.self) }
        swiftTypeHandlers.pointee["SwiftUI.Alignment"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.Alignment.self) }
        swiftTypeHandlers.pointee["SwiftUI.Image"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.Image.self) }
        swiftTypeHandlers.pointee["SwiftUI.LocalizedStringKey"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.LocalizedStringKey.self) }
    }
}
