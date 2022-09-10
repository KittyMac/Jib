#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch
import Chronometer

public class Jib {
    public let context: JSGlobalContextRef
    public let group: JSContextGroupRef
    public let global: JSObjectRef
    public let undefined: JSObjectRef
    public let `true`: JSObjectRef
    public let `false`: JSObjectRef
    
    public var exception: Hitch?
    
    private var printFn: JibFunction? = nil
    
    @usableFromInline
    let lock = NSLock()
    
    deinit {
        lock.lock(); defer { lock.unlock() }
        JSContextGroupRelease(group)
        JSGlobalContextRelease(context)
    }
    
    public init() {
        group = JSContextGroupCreate()
        context = JSGlobalContextCreateInGroup(group, nil)
        global = JSContextGetGlobalObject(context)
        undefined = JSValueMakeUndefined(context)
        self.true = JSValueMakeBoolean(context, true)
        self.false = JSValueMakeBoolean(context, false)
        
        printFn = new(function: "print", body: { arguments in
            for argument in arguments {
                print(argument)
            }
            return nil
        })
        
        if let printFn = printFn {
            set(global: "print", value: printFn)
            _ = eval("console = {}; console.log = print;")
        } else {
            print("warning: jibPrint failed to be created, console.log will not work")
        }
    }
    
    @discardableResult
    public func call(_ function: JibFunction, _ args: [JibUnknown?]) -> Hitch? {
        lock.lock(); defer { lock.unlock() }
        
        var jsException: JSObjectRef? = nil
        
        let convertedArgs = args.map { $0?.createJibValue(self) }
                
        let jsValue = JSObjectCallAsFunction(context, function.objectRef, nil, convertedArgs.count, convertedArgs, &jsException)
        
        if let jsException = jsException {
            return record(exception: jsException)
        }

        return JSValueToHitch(context, jsValue)
    }
    
    public func garbageCollect() {
        lock.lock(); defer { lock.unlock() }
        
        JSGarbageCollect(context)
    }
    
    // MARK: - JS Creation
    
    @discardableResult
    public func new(function name: HalfHitch, body: @escaping JibFunctionBody) -> JibFunction? {
        lock.lock(); defer { lock.unlock() }
        
        return JibFunction(jib: self, name: name, body: body)
    }
    
    @discardableResult
    public func set(global name: HalfHitch, value: JibValue) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        
        let jsString = CreateJSString(halfhitch: name)
        defer { JSStringRelease(jsString) }
        
        var jsException: JSObjectRef? = nil
                
        JSObjectSetProperty(context, global, jsString, value, UInt32(kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontEnum | kJSPropertyAttributeDontDelete), &jsException)
        if let jsException = jsException {
            return record(exception: jsException)
        }
        
        return true
    }
    
    @discardableResult
    public func set(global name: HalfHitch, value: JibFunction) -> Bool? {
        return set(global: name, value: value.objectRef ?? undefined)
    }
    
    // MARK: - JS Resolution
    public func eval(_ script: HalfHitch) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        
        // if that fails, attempt to resolve by evaluating it as a script
        guard let raw = script.raw() else { return nil }
        
        let jsScript = JSStringCreateWithUTF8CString(raw)
        defer { JSStringRelease(jsScript) }

        var jsException: JSObjectRef? = nil
        JSEvaluateScript(context, jsScript, nil, nil, 0, &jsException)
        if let jsException = jsException {
            return record(exception: jsException)
        }
                
        return true
    }
    @inlinable @inline(__always) public func eval(_ script: Hitch) -> Bool? { return eval(script.halfhitch()) }
    @inlinable @inline(__always) public func eval(_ script: String) -> Bool? { return eval(HalfHitch(string: script)) }
    @inlinable @inline(__always) public func eval(_ script: StaticString) -> Bool? { return eval(HalfHitch(stringLiteral: script)) }
    
    // MARK: - JS Resolution
    
    @inlinable @inline(__always)
    public subscript (function exec: HalfHitch) -> JibFunction? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let value = resolve(exec) else { return nil }
            guard JSValueIsUndefined(context, value) == false else { return nil }
            guard JSObjectIsFunction(context, value) == true else { return nil }
            return JibFunction(jib: self, object: value)
        }
    }
    @inlinable @inline(__always) public subscript (function exec: Hitch) -> JibFunction? { get { return self[function: exec.halfhitch()] } }
    @inlinable @inline(__always) public subscript (function exec: String) -> JibFunction? { get { return self[function: HalfHitch(string: exec)] } }
    @inlinable @inline(__always) public subscript (function exec: StaticString) -> JibFunction? { get { return self[function: HalfHitch(stringLiteral: exec)] } }
    
    @inlinable @inline(__always)
    public subscript (hitch exec: HalfHitch) -> Hitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let value = resolve(exec) else { return nil }
            return JSValueToHitch(context, value)
        }
    }
    @inlinable @inline(__always) public subscript (hitch exec: Hitch) -> Hitch? { get { return self[hitch: exec.halfhitch()] } }
    @inlinable @inline(__always) public subscript (hitch exec: String) -> Hitch? { get { return self[hitch: HalfHitch(string: exec)] } }
    @inlinable @inline(__always) public subscript (hitch exec: StaticString) -> Hitch? { get { return self[hitch: HalfHitch(stringLiteral: exec)] } }
    
    @inlinable @inline(__always)
    public subscript (halfhitch exec: HalfHitch) -> HalfHitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let value = resolve(exec) else { return nil }
            return JSValueToHitch(context, value).halfhitch()
        }
    }
    @inlinable @inline(__always) public subscript (halfhitch exec: Hitch) -> HalfHitch? { get { return self[halfhitch: exec.halfhitch()] } }
    @inlinable @inline(__always) public subscript (halfhitch exec: String) -> HalfHitch? { get { return self[halfhitch: HalfHitch(string: exec)] } }
    @inlinable @inline(__always) public subscript (halfhitch exec: StaticString) -> HalfHitch? { get { return self[halfhitch: HalfHitch(stringLiteral: exec)] } }
    
    @inlinable @inline(__always)
    public subscript (string exec: HalfHitch) -> String? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let value = resolve(exec) else { return nil }
            return JSValueToHitch(context, value).description
        }
    }
    @inlinable @inline(__always) public subscript (string exec: Hitch) -> String? { get { return self[string: exec.halfhitch()] } }
    @inlinable @inline(__always) public subscript (string exec: String) -> String? { get { return self[string: HalfHitch(string: exec)] } }
    @inlinable @inline(__always) public subscript (string exec: StaticString) -> String? { get { return self[string: HalfHitch(stringLiteral: exec)] } }
    
    @inlinable @inline(__always)
    public subscript (date exec: HalfHitch) -> Date? {
        get {
            guard let value = self[hitch: exec] else { return nil }
            return value.description.date()
        }
    }
    @inlinable @inline(__always) public subscript (date exec: Hitch) -> Date? { get { return self[date: exec.halfhitch()] } }
    @inlinable @inline(__always) public subscript (date exec: String) -> Date? { get { return self[date: HalfHitch(string: exec)] } }
    @inlinable @inline(__always) public subscript (date exec: StaticString) -> Date? { get { return self[date: HalfHitch(stringLiteral: exec)] } }
    
    @inlinable @inline(__always)
    public subscript (double exec: HalfHitch) -> Double? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let value = resolve(exec) else { return nil }
            guard JSValueIsUndefined(context, value) == false else { return nil }
            guard JSValueIsNumber(context, value) == true else { return nil }
            
            var jsException: JSObjectRef? = nil
            let number = JSValueToNumber(context, value, &jsException)
            if let jsException = jsException {
                return record(exception: jsException)
            }
            return number
        }
    }
    @inlinable @inline(__always) public subscript (double exec: Hitch) -> Double? { get { return self[double: exec.halfhitch()] } }
    @inlinable @inline(__always) public subscript (double exec: String) -> Double? { get { return self[double: HalfHitch(string: exec)] } }
    @inlinable @inline(__always) public subscript (double exec: StaticString) -> Double? { get { return self[double: HalfHitch(stringLiteral: exec)] } }
    
    @inlinable @inline(__always)
    public subscript (int exec: HalfHitch) -> Int? {
        get {
            guard let number = self[double: exec] else { return nil }
            return Int(number)
        }
    }
    @inlinable @inline(__always) public subscript (int exec: Hitch) -> Int? { get { return self[int: exec.halfhitch()] } }
    @inlinable @inline(__always) public subscript (int exec: String) -> Int? { get { return self[int: HalfHitch(string: exec)] } }
    @inlinable @inline(__always) public subscript (int exec: StaticString) -> Int? { get { return self[int: HalfHitch(stringLiteral: exec)] } }
    
    @inlinable @inline(__always)
    public subscript (bool exec: HalfHitch) -> Bool? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let value = resolve(exec) else { return nil }
            guard JSValueIsUndefined(context, value) == false else { return nil }
            guard JSValueIsBoolean(context, value) == true else { return nil }
            return JSValueToBoolean(context, value)
        }
    }
    @inlinable @inline(__always) public subscript (bool exec: Hitch) -> Bool? { get { return self[bool: exec.halfhitch()] } }
    @inlinable @inline(__always) public subscript (bool exec: String) -> Bool? { get { return self[bool: HalfHitch(string: exec)] } }
    @inlinable @inline(__always) public subscript (bool exec: StaticString) -> Bool? { get { return self[bool: HalfHitch(stringLiteral: exec)] } }
    
    @inlinable @inline(__always)
    public subscript (json exec: HalfHitch) -> Hitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let value = resolve(exec) else { return nil }
            guard JSValueIsUndefined(context, value) == false else { return nil }
            return JSValueToJson(context, value)
        }
    }
    @inlinable @inline(__always) public subscript (json exec: Hitch) -> Hitch? { get { return self[json: exec.halfhitch()] } }
    @inlinable @inline(__always) public subscript (json exec: String) -> Hitch? { get { return self[json: HalfHitch(string: exec)] } }
    @inlinable @inline(__always) public subscript (json exec: StaticString) -> Hitch? { get { return self[json: HalfHitch(stringLiteral: exec)] } }
    
    @discardableResult
    @inlinable @inline(__always)
    func resolve(_ hitch: HalfHitch) -> JSValueRef? {
        // given the hitch, first attempt to resolve to a global. it is arbitrary,
        // but we are going to assume that names to global variables as < 128 characters
        // long to avoid having to create and release large scripts
        
        exception = nil
        
        if hitch.count < 128,
           let jsString = CreateJSString(halfhitch: hitch) {
            defer { JSStringRelease(jsString) }
            if let value = JSObjectGetProperty(context, global, jsString, nil),
               JSValueIsUndefined(context, value) == false {
                return value
            }
        }
        
        // if that fails, attempt to resolve by evaluating it as a script
        let modifiedHitch = "({0})" << [hitch]
        guard let raw = modifiedHitch.raw() else { return undefined }

        // JavascriptCore does not appear to evaluation object literals correctly, it will
        // always return undefined unless it is embedded in parens
        let jsScript = JSStringCreateWithUTF8CString(raw)
        defer { JSStringRelease(jsScript) }

        var jsException: JSObjectRef? = nil
        let jsValue = JSEvaluateScript(context, jsScript, nil, nil, 0, &jsException)
        if let jsException = jsException {
            return record(exception: jsException)
        }
                
        return jsValue ?? undefined
    }
    
    @discardableResult
    @inlinable @inline(__always)
    func record<T>(exception jsException: JSObjectRef) -> T? {
        self.exception = JSValueToHitch(context, jsException)
        print(exception ?? "unknown exception occurred")
        return nil
    }
}
