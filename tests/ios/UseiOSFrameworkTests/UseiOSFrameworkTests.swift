//
//  UseiOSFrameworkTests.swift
//  UseiOSFrameworkTests
//
//  Created by Drew Crawford on 5/11/16.
//  Copyright © 2016 Drew Crawford. All rights reserved.
//

import XCTest
@testable import UseiOSFramework
import FooFramework

class UseiOSFrameworkTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let _ = Foo()
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
