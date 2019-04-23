//
//  NSObjectSwiftInjection.swift
//  InjectionBundle
//
//  Created by Francisco Javier Trujillo Mata on 23/04/2019.
//  Copyright © 2019 John Holdsworth. All rights reserved.
//

import Foundation

public extension NSObject {
    
    func inject() {
        if let oldClass: AnyClass = object_getClass(self) {
            SwiftInjection().inject(oldClass: oldClass, classNameOrFile: "\(oldClass)")
        }
    }
    
    @objc
    class func inject(file: String) {
        SwiftInjection().inject(oldClass: nil, classNameOrFile: file)
    }
}
