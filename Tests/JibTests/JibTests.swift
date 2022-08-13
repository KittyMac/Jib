import XCTest
import JibFramework

final class JibTests: XCTestCase {
    
    func testExec() {        
        XCTAssertEqual(try? Jib().exec(#" `Hello World` "#), "Hello World")
    }
    
    func testCallArgs0() throws {
        let jib = Jib()
        
        try jib.exec("function hello() { return `hello` }")
        
        guard let helloFunc = jib[function: "hello"] else {
            XCTFail("unable to extract global function hello")
            return
        }
        
        XCTAssertEqual(try jib.call(helloFunc, []), "hello")
        
        XCTAssertEqual(try jib.exec(#"hello()"#), "hello")
    }
    
    func testCallArgs1() throws {
        let jib = Jib()
        
        try jib.exec("function uppercase(arg1) { return arg1.toUpperCase(); }")
        
        XCTAssertEqual(try jib.exec(#"uppercase(`hello world`)"#), "HELLO WORLD")
        
        guard let uppercaseFunc = jib[function: "uppercase"] else {
            XCTFail("unable to extract global function hello")
            return
        }
        
        XCTAssertEqual(try jib.call(uppercaseFunc, ["hello world"]), "HELLO WORLD")
    }
    
    func testCallArgs2() throws {
        let jib = Jib()
        
        try jib.exec("function add(x, y) { return x + y }")
                
        guard let addFunc = jib[function: "add"] else {
            XCTFail("unable to extract global function hello")
            return
        }
        
        XCTAssertEqual(try jib.call(addFunc, [2, 3]), "5")
    }
    
    func testCallArgs3() throws {
        let jib = Jib()
        
        let callback = jib.function(name: "test") { args in
            print("HI")
            return nil
        }
                
        try jib.exec("function callback(x, f) { f(x); }")
                
        guard let callbackFunc = jib[function: "callback"] else {
            XCTFail("unable to extract global function hello")
            return
        }
        
        XCTAssertEqual(try jib.call(callbackFunc, [1, callback]), "1")
    }
    
    func testException() {
        let jib = Jib()
        do {
            try jib.exec(#" x.hello() "#)
        } catch {
            XCTAssertEqual("\(error)", "ReferenceError: Can't find variable: x")
            return
        }
        XCTFail()
    }
    
    func testMemoryLeak() throws {
        
        let jib = Jib()
        
        if true {
            for _ in 0..<10000 {
                try jib.exec("41+1")
            }
        }
        
    }
}
