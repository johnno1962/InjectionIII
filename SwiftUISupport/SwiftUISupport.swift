//
//  SwiftUISupport.swift
//  SwiftUISupport
//
//  Created by John Holdsworth on 25/09/2020.
//  Copyright © 2020 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/SwiftUISupport/SwiftUISupport.swift#10 $
//

import SwiftUI
import SwiftTrace

extension SwiftUI.EdgeInsets: SwiftTraceFloatArg {}

@objc (SwiftUISupport)
class SwiftUISupport: NSObject {

    @objc class func setup(pointer: UnsafeMutableRawPointer?) {

        print("💉 Installed SwiftUI type handlers")
        SwiftTrace.addFormattedType(SwiftUI.Text.self)
        SwiftTrace.addFormattedType(SwiftUI.Color.self)
        SwiftTrace.addFormattedType(SwiftUI.Image.self)
        SwiftTrace.addFormattedType(SwiftUI.Edge.Set.self)
        SwiftTrace.addFormattedType(SwiftUI.Alignment.self)
        SwiftTrace.addFormattedType(SwiftUI.EdgeInsets.self)
        SwiftTrace.addFormattedType(SwiftUI.LocalizedStringKey.self)
    }
}
