import XCTest
import Jib
import Hitch

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

final class JibTests: XCTestCase {
    
    func testNullTerminatedHalfHitch() {
        let scriptWhole: Hitch = "1234567890global.x = 5123456789"
        let scriptPart: HalfHitch = HalfHitch(source: scriptWhole, from: 10, to: 22)
        
        let jib1 = Jib()
        jib1.eval(scriptPart)
        let result1 = jib1[int: "x"]!
        XCTAssertEqual(result1, 5)
    }
    
    func testClone() {
        let jib1 = Jib()
        jib1.eval(#"global.x = 5"#)
        let result1 = jib1[int: "x"]!
        XCTAssertEqual(result1, 5)
        
        let jib2 = Jib(clone: jib1)
        let result2 = jib2[int: "x"]!
        XCTAssertEqual(result2, 5)
    }
    
    func testGlobal0() {
        let jib = Jib()
        jib.eval(#"global.x = 5"#)
        let result1 = jib[int: "x"]!
        XCTAssertEqual(result1, 5)
    }
    
    func testGlobal1() {
        let jib = Jib()
        jib.eval(#"x = 5"#)
        let result1 = jib[int: "global.x"]!
        XCTAssertEqual(result1, 5)
    }
    
    func testJson() {
        let jib = Jib()
                
        let result1 = jib[json: #"{  a  :  1}"#]!
        XCTAssertEqual(result1, #"{"a":1}"#)
    }
    
    func testCodable() {
        struct Config: Codable {
            let time: Int
            let delay: Int
            let command: String
        }
        let jib = Jib()
                
        let result1: Config = jib[decoded: #"{time:60,delay:100,command:"run"}"#]!
        XCTAssertEqual(result1.time, 60)
        XCTAssertEqual(result1.delay, 100)
        XCTAssertEqual(result1.command, "run")
    }
    
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
        _ = jib.eval("""
        var testString = "Hello World"
        var testInt = 4
        var testDouble = 1.234
        var testBool = true
        var testDate = Date()
        """)
        
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
    
    func testPrint() {
        let jib = Jib()
        
        _ = jib.eval("print('hello world')")!
        _ = jib.eval("console.log('hello world')")!
    }
    
    func testException() {
        let jib = Jib()
        
        guard let _ = jib.eval(" x.hello() ") else {
            XCTAssertEqual(jib.exception, "ReferenceError: Can't find variable: x")
            return
        }
    }
    
    func testPassJibFunctionToFunction() {
        let jib = Jib()
        
        let printFunction = jib.new(function: "print", body: { arguments in
            for argument in arguments {
                print(argument)
            }
            return nil
        })
        
        guard let helloFunc = jib[function: "(function (fn,value) { fn(value); return value; })"] else {
            XCTFail("unable to resolve function hello")
            return
        }
        
        XCTAssertEqual(jib.call(hitch: helloFunc, [printFunction, "hello world"]), "hello world")
    }
    
    func testCallFunctionNone() {
        let jib = Jib()
        
        guard let helloFunc = jib[function: "(function () { print(`hello`) })"] else {
            XCTFail("unable to resolve function hello")
            return
        }
        
        XCTAssertNotNil(jib.call(none: helloFunc, []))
    }
    
    func testCallFunction0() {
        let jib = Jib()
        
        guard let helloFunc = jib[function: "(function () { return `hello` })"] else {
            XCTFail("unable to resolve function hello")
            return
        }
        
        XCTAssertEqual(jib.call(hitch: helloFunc, []), "hello")
    }
    
    func testCallArgs1() throws {
        let jib = Jib()
        
        _ = jib.eval("function uppercase(arg1) { return arg1.toUpperCase(); }")
        
        XCTAssertEqual(jib[string: "uppercase(`hello world`)"], "HELLO WORLD")
        
        guard let uppercaseFunc = jib[function: "uppercase"] else {
            XCTFail("unable to extract global function hello")
            return
        }
        
        XCTAssertEqual(jib.call(hitch: uppercaseFunc, ["hello world"]), "HELLO WORLD")
    }
    
    func testCallArgs2() throws {
        let jib = Jib()
        
        _ = jib.eval("function add(x, y) { return x + y }")
                
        guard let addFunc = jib[function: "add"] else {
            XCTFail("unable to extract global function hello")
            return
        }
        
        XCTAssertEqual(jib.call(hitch: addFunc, [2, 3]), "5")
    }
    
    func testCallArgs3() throws {
        let jib = Jib()
        
        let swiftUppercase = jib.new(function: "swiftUppercase") { args in
            return args.map { $0.uppercase() }
        }!
        
        _ = jib.eval("function callback(x, f) { return f(x); }")
                
        guard let callbackFunc = jib[function: "callback"] else {
            XCTFail("unable to extract global function hello")
            return
        }
    
        XCTAssertEqual(jib.call(hitch: callbackFunc, ["hello world", swiftUppercase]), "HELLO WORLD")
    }
    
    func testThreadSafety() throws {
        let jib = Jib()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 20
        
        
        for _ in 0..<10 {
            queue.addOperation {
                let swiftUppercase = jib.new(function: "swiftUppercase") { args in
                    return args.map { $0.uppercase() }
                }!
                
                _ = jib.eval("function callback(x, f) { return f(x); }")
                        
                let callbackFunc = jib[function: "callback"]!
                
                for _ in 0..<100000 {
                    queue.addOperation {
                        let result = jib.call(hitch: callbackFunc, ["hello world", swiftUppercase])
                        XCTAssertEqual(result, "HELLO WORLD")
                    }
                }
            }
        }
        
        queue.waitUntilAllOperationsAreFinished()
    }
    
    func testParallelJib() throws {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 20

        for _ in 0..<queue.maxConcurrentOperationCount {
            queue.addOperation {
                let jib = Jib()
                
                let sleepFunction = jib.new(function: "sleep") { args in
                    Thread.sleep(forTimeInterval: 3.0)
                    return nil
                }!
                
                jib.set(global: "sleep", value: sleepFunction)
                
                let start = Date()
                jib.eval("""
                    sleep(3)
                """)
                print("concurrent js time: \(abs(start.timeIntervalSinceNow))")
            }
        }
        queue.waitUntilAllOperationsAreFinished()
    }
    
    func testConvenience() {
        let jib = Jib()
        
        let staticString: StaticString = "StaticString"
        _ = jib.eval(staticString)
        
        let string: String = "String"
        _ = jib.eval(string)
        
        let hitch: Hitch = "Hitch"
        _ = jib.eval(hitch)
        
        let halfhitch: HalfHitch = "HalfHitch"
        _ = jib.eval(halfhitch)
    }
    
    func testMemoryLeak() throws {
        
        let jib = Jib()
        
        if true {
            for _ in 0..<10000 {
                _ = jib.eval("41+1")
            }
        }
        
    }
}
