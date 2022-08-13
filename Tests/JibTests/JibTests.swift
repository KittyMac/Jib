import XCTest
import Jib
import Hitch

final class JibTests: XCTestCase {
    
    func testResolution() {
        let jib = Jib()
        
        // resolving scripts to types
        let result1 = jib[string: #" `Hello World`; "#]!
        XCTAssertEqual(result1, "Hello World")
        
        let result2 = jib[hitch: #" `Hello World`; "#]!
        XCTAssertEqual(result2, "Hello World")
        
        let result3 = jib[halfhitch: #" `Hello World`; "#]!
        XCTAssertEqual(result3, "Hello World")
        
        let result4 = jib[int: #" 4 "#]!
        XCTAssertEqual(result4, 4)
        
        let result5 = jib[double: #" 1.234 "#]!
        XCTAssertEqual(result5, 1.234)
        
        let result6 = jib[bool: #" true "#]!
        XCTAssertEqual(result6, true)
        
        let result7 = jib[date: #" Date() "#]!
        XCTAssertTrue(result7 < Date.distantFuture)
        XCTAssertTrue(result7 > Date.distantPast)
        
        // resolving global objects to types
        _ = jib[eval: """
        var testString = "Hello World"
        var testInt = 4
        var testDouble = 1.234
        var testBool = true
        var testDate = Date()
        """]
        
        let result1b = jib[string: "testString"]!
        XCTAssertEqual(result1b, "Hello World")
        
        let result2b = jib[hitch: "testString"]!
        XCTAssertEqual(result2b, "Hello World")
        
        let result3b = jib[halfhitch: "testString"]!
        XCTAssertEqual(result3b, "Hello World")
        
        let result4b = jib[int: "testInt"]!
        XCTAssertEqual(result4b, 4)
        
        let result5b = jib[double: "testDouble"]!
        XCTAssertEqual(result5b, 1.234)
        
        let result6b = jib[bool: "testBool"]!
        XCTAssertEqual(result6b, true)
        
        let result7b = jib[date: "testDate"]!
        XCTAssertTrue(result7b < Date.distantFuture)
        XCTAssertTrue(result7b > Date.distantPast)
    }
    
    func testException() {
        let jib = Jib()
        
        guard let _ = jib[eval: " x.hello() "] else {
            XCTAssertEqual(jib.exception, "ReferenceError: Can't find variable: x")
            return
        }
    }
    
    func testCallFunction0() {
        let jib = Jib()
        
        _ = jib[eval: """
        function hello() { return `hello` }
        """]
        
        guard let helloFunc = jib[function: "hello"] else {
            XCTFail("unable to resolve function hello")
            return
        }
        
        XCTAssertEqual(try jib.call(helloFunc, []), "hello")
    }
    
    func testCallArgs1() throws {
        let jib = Jib()
        
        _ = jib[eval: "function uppercase(arg1) { return arg1.toUpperCase(); }"]
        
        XCTAssertEqual(jib[string: "uppercase(`hello world`)"], "HELLO WORLD")
        
        guard let uppercaseFunc = jib[function: "uppercase"] else {
            XCTFail("unable to extract global function hello")
            return
        }
        
        XCTAssertEqual(try jib.call(uppercaseFunc, ["hello world"]), "HELLO WORLD")
    }
    
    func testCallArgs2() throws {
        let jib = Jib()
        
        _ = jib[eval: "function add(x, y) { return x + y }"]
                
        guard let addFunc = jib[function: "add"] else {
            XCTFail("unable to extract global function hello")
            return
        }
        
        XCTAssertEqual(try jib.call(addFunc, [2, 3]), "5")
    }
    
    func testCallArgs3() throws {
        let jib = Jib()
        
        let swiftUppercase = jib.new(function: "swiftUppercase") { args in
            return args.map { $0.uppercase() }
        }!
        
        _ = jib[eval: "function callback(x, f) { return f(x); }"]
                
        guard let callbackFunc = jib[function: "callback"] else {
            XCTFail("unable to extract global function hello")
            return
        }
    
        XCTAssertEqual(try jib.call(callbackFunc, ["hello world", swiftUppercase]), "HELLO WORLD")
    }
    
    func testMemoryLeak() throws {
        
        let jib = Jib()
        
        if true {
            for _ in 0..<10000 {
                _ = jib[eval: "41+1"]
            }
        }
        
    }
}
