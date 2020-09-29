//
//  SwiftUISupport.swift
//  SwiftUISupport
//
//  Created by John Holdsworth on 25/09/2020.
//  Copyright © 2020 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/SwiftUISupport/SwiftUISupport.swift#9 $
//

import SwiftUI
import SwiftTrace

extension SwiftUI.EdgeInsets: SwiftTraceFloatArg {}

@objc (SwiftUISupport)
class SwiftUISupport: NSObject {

    @objc class func setup(pointer: UnsafeMutableRawPointer?) {

        print("💉 Installed SwiftUI type handlers")
        SwiftTrace.addFormattedType(SwiftUI.Text.self, prefix: "SwiftUI")
        SwiftTrace.addFormattedType(SwiftUI.Color.self, prefix: "SwiftUI")
        SwiftTrace.addFormattedType(SwiftUI.Image.self, prefix: "SwiftUI")
        SwiftTrace.addFormattedType(SwiftUI.Edge.Set.self, prefix: "SwiftUI")
        SwiftTrace.addFormattedType(SwiftUI.Alignment.self, prefix: "SwiftUI")
        SwiftTrace.addFormattedType(SwiftUI.EdgeInsets.self, prefix: "SwiftUI")
        SwiftTrace.addFormattedType(SwiftUI.LocalizedStringKey.self, prefix: "SwiftUI")
    }
}
