//
//  XCTestSwiftInjection.swift
//  InjectionBundle
//
//  Created by Francisco Javier Trujillo Mata on 23/04/2019.
//  Copyright © 2019 John Holdsworth. All rights reserved.
//

import Foundation
import XCTest

@objc
public class XCTestSwiftInjection: SwiftInjection {

    static let testQueue = DispatchQueue(label: "INTestQueue")
    var testClasses = [AnyClass]()
    
    override func appendTestClass(_ newClass: AnyClass) {
        if newClass.isSubclass(of: XCTestCase.self) {
            testClasses.append(newClass)
        }
    }
    
    override func proceedTestClasses()  {
        // Thanks https://github.com/johnno1962/injectionforxcode/pull/234
        if !testClasses.isEmpty {
            XCTestSwiftInjection.testQueue.async {
                XCTestSwiftInjection.testQueue.suspend()
                let timer = Timer(timeInterval: 0, repeats:false, block: { _ in
                    for newClass in self.testClasses {
                        let suite0 = XCTestSuite(name: "Injected")
                        let suite = XCTestSuite(forTestCaseClass: newClass)
                        let tr = XCTestSuiteRun(test: suite)
                        suite0.addTest(suite)
                        suite0.perform(tr)
                    }
                    XCTestSwiftInjection.testQueue.resume()
                })
                RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
            }
        }
    }
        
}
