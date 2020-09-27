//
//  SwiftUISupport.swift
//  SwiftUISupport
//
//  Created by John Holdsworth on 25/09/2020.
//  Copyright © 2020 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/SwiftUISupport/SwiftUISupport.swift#5 $
//

import SwiftUI
import SwiftTrace

extension SwiftUI.EdgeInsets: SwiftTraceFloatArg {}

@objc (SwiftUISupport)
class SwiftUISupport: NSObject {

    @objc class func setup(pointer: UnsafeMutableRawPointer) {

        print("💉 Installed SwiftUI type handlers")
        SwiftTrace.Decorated.swiftTypeHandlers["SwiftUI.Text"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.Text.self) }
        SwiftTrace.Decorated.swiftTypeHandlers["SwiftUI.Color"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.Color.self) }
        SwiftTrace.Decorated.swiftTypeHandlers["SwiftUI.Edge.Set"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.Edge.Set.self) }
        SwiftTrace.Decorated.swiftTypeHandlers["SwiftUI.EdgeInsets"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.EdgeInsets.self) }
        SwiftTrace.Decorated.swiftTypeHandlers["SwiftUI.Alignment"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.Alignment.self) }
        SwiftTrace.Decorated.swiftTypeHandlers["SwiftUI.Image"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.Image.self) }
        SwiftTrace.Decorated.swiftTypeHandlers["SwiftUI.LocalizedStringKey"] =
            { SwiftTrace.Decorated.handleArg(invocation: $0, isReturn: $1, type: SwiftUI.LocalizedStringKey.self) }
    }
}
