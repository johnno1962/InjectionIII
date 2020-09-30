//
//  SwiftEvalTests.swift
//  SwiftEvalTests
//
//  Created by John Holdsworth on 02/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

import XCTest

class SwiftEvalTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual("123", swiftEvalString(contents: "123"), "Basic eval test")
        XCTAssertEqual(123, swiftEval("123", type: Int.self), "Basic eval test")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            XCTAssertEqual("1234", swiftEvalString(contents: "1234"), "eval performance test")
        }
    }
    
}
