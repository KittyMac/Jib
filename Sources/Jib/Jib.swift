#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch
import Chronometer

extension Hitch {
    @usableFromInline
    func jsString<T>(_ callback: (JSStringRef) -> (T?)) -> T? {
        return self.using { raw, count in
            guard let raw = raw else { return nil }
            // Note: it should not be possible for a hitch to not be null terminated, however
            // we are putting this in as a safety measure
            if raw[count] == 0 {
                guard let jsstring = JSStringCreateWithUTF8CString(raw) else { return nil }
                return callback(jsstring)
            }
            return nil
        }
    }
}

extension HalfHitch {
    @usableFromInline
    func jsString<T>(_ callback: (JSStringRef) -> (T?)) -> T? {
        return self.using { raw, count in
            guard let raw = raw else { return nil }
            // Note: there is not a garauntee that halfhitch ends with a null terminator,
            // so we check it first. If it does not, we need to make a copy.
            if raw[count] == 0 {
                guard let jsstring = JSStringCreateWithUTF8CString(raw) else { return nil }
                return callback(jsstring)
            }
            return hitch().jsString(callback)
        }
    }
}

public class Jib {
    
    public let group: JSContextGroupRef
    public let context: JSGlobalContextRef
    public let global: JSObjectRef
    public let undefined: JSObjectRef
    public let `true`: JSObjectRef
    public let `false`: JSObjectRef
    
    public var exception: Hitch?
    
    private var printFn: JibFunction? = nil
    
    private var customFunctions: [JibFunction] = []
    
    @usableFromInline
    let lock = NSLock()
    
    deinit {
        lock.lock(); defer { lock.unlock() }
        JSGlobalContextRelease(context)
        JSContextGroupRelease(group)
    }
    
    public init(clone: Jib? = nil) {
        group = JSContextGroupCreate()
        context = JSGlobalContextCreateInGroup(group, nil)
        global = JSContextGetGlobalObject(context)
        undefined = JSValueMakeUndefined(context)
        self.true = JSValueMakeBoolean(context, true)
        self.false = JSValueMakeBoolean(context, false)
        
        if let clone = clone,
           let cloneGlobal = JSContextGetGlobalObject(clone.context) {
            let names = JSObjectCopyPropertyNames(clone.context, cloneGlobal)
            for idx in 0..<JSPropertyNameArrayGetCount(names) {
                let name = JSPropertyNameArrayGetNameAtIndex(names, idx)
                let value = JSObjectGetProperty(clone.context, cloneGlobal, name, nil)
                JSObjectSetProperty(context, global, name, value, UInt32(kJSPropertyAttributeDontDelete), nil)
            }
            JSPropertyNameArrayRelease(names)
        }
        
        set(global: "global", value: global)
        
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
    
    private func call(jsvalue function: JibFunction, _ args: [JibUnknown?]) -> JSValueRef? {
        lock.lock(); defer { lock.unlock() }
        var jsException: JSObjectRef? = nil
        let convertedArgs = args.map { $0?.createJibValue(self) }
        if args.count != convertedArgs.count {
            self.exception = "jib.call failed to convert all arguments to JSValues"
            // print(exception ?? "unknown exception occurred")
            return nil
        }
        let jsValue = JSObjectCallAsFunction(context, function.objectRef, nil, convertedArgs.count, convertedArgs, &jsException)
        if let jsException = jsException {
            return record(exception: jsException)
        }
        return jsValue
    }
    
    public func call<T: Decodable>(decoded function: JibFunction, _ args: [JibUnknown?]) -> T? { return JSValueToDecodable(context, call(jsvalue: function, args)) }
    public func call(function: JibFunction, _ args: [JibUnknown?]) -> JibFunction? { return JSValueToFunction(self, call(jsvalue: function, args)) }
    public func call(hitch function: JibFunction, _ args: [JibUnknown?]) -> Hitch? { return JSValueToHitch(context, call(jsvalue: function, args)) }
    public func call(halfhitch function: JibFunction, _ args: [JibUnknown?]) -> HalfHitch? { return JSValueToHitch(context, call(jsvalue: function, args))?.halfhitch() }
    public func call(string function: JibFunction, _ args: [JibUnknown?]) -> String? { return JSValueToHitch(context, call(jsvalue: function, args))?.toString() }
    public func call(date function: JibFunction, _ args: [JibUnknown?]) -> Date? { return JSValueToHitch(context, call(jsvalue: function, args))?.toString().date() }
    public func call(double function: JibFunction, _ args: [JibUnknown?]) -> Double? { return JSValueToDouble(context, call(jsvalue: function, args)) }
    public func call(int function: JibFunction, _ args: [JibUnknown?]) -> Int? { return JSValueToInt(context, call(jsvalue: function, args)) }
    public func call(bool function: JibFunction, _ args: [JibUnknown?]) -> Bool? { return JSValueToBool(context, call(jsvalue: function, args)) }
    public func call(json function: JibFunction, _ args: [JibUnknown?]) -> Hitch? { return JSValueToJson(context, call(jsvalue: function, args)) }
    public func call(none function: JibFunction, _ args: [JibUnknown?]) -> Any? { return call(jsvalue: function, args) != nil }
    
    public func garbageCollect() {
        lock.lock(); defer { lock.unlock() }
        
        JSGarbageCollect(context)
    }
    
    // MARK: - JS Creation
    
    @discardableResult
    public func new(function name: HalfHitch, body: @escaping JibFunctionBody) -> JibFunction? {
        lock.lock(); defer { lock.unlock() }
        
        guard let function = JibFunction(jib: self, name: name, body: body) else { return nil }
        customFunctions.append(function)
        return function
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
    
    // MARK: - JS Evaluation
    @discardableResult
    public func eval(_ script: HalfHitch) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        
        // if that fails, attempt to resolve by evaluating it as a script
        return script.jsString { jsScript in
            defer { JSStringRelease(jsScript) }

            var jsException: JSObjectRef? = nil
            JSEvaluateScript(context, jsScript, nil, nil, 0, &jsException)
            if let jsException = jsException {
                return record(exception: jsException)
            }
                    
            return true
        }
    }
    @discardableResult
    @inlinable public func eval(_ script: Hitch) -> Bool? { return eval(script.halfhitch()) }
    @discardableResult
    @inlinable public func eval(_ script: String) -> Bool? { return eval(HalfHitch(string: script)) }
    @discardableResult
    @inlinable public func eval(_ script: StaticString) -> Bool? { return eval(HalfHitch(stringLiteral: script)) }
    @discardableResult
    @inlinable public func eval(_ script: Data) -> Bool? { return eval(HalfHitch(data: script)) }
    
    // MARK: - JS Resolution
    
    
    
    @inlinable
    public subscript<T: Decodable> (decoded exec: HalfHitch) -> T? {
        get {
            lock.lock(); defer { lock.unlock() }
            return JSValueToDecodable(context, resolve(exec))
        }
    }
    @inlinable public subscript<T: Decodable> (decoded exec: Hitch) -> T? { get { return self[decoded: exec.halfhitch()] } }
    @inlinable public subscript<T: Decodable> (decoded exec: String) -> T? { get { return self[decoded: HalfHitch(string: exec)] } }
    @inlinable public subscript<T: Decodable> (decoded exec: StaticString) -> T? { get { return self[decoded: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript<T: Decodable> (decoded exec: Data) -> T? { get { return self[decoded: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (function exec: HalfHitch) -> JibFunction? {
        get {
            lock.lock(); defer { lock.unlock() }
            return JSValueToFunction(self, resolve(exec))
        }
    }
    @inlinable public subscript (function exec: Hitch) -> JibFunction? { get { return self[function: exec.halfhitch()] } }
    @inlinable public subscript (function exec: String) -> JibFunction? { get { return self[function: HalfHitch(string: exec)] } }
    @inlinable public subscript (function exec: StaticString) -> JibFunction? { get { return self[function: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (function exec: Data) -> JibFunction? { get { return self[function: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (hitch exec: HalfHitch) -> Hitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            return JSValueToHitch(context, resolve(exec))
        }
    }
    @inlinable public subscript (hitch exec: Hitch) -> Hitch? { get { return self[hitch: exec.halfhitch()] } }
    @inlinable public subscript (hitch exec: String) -> Hitch? { get { return self[hitch: HalfHitch(string: exec)] } }
    @inlinable public subscript (hitch exec: StaticString) -> Hitch? { get { return self[hitch: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (hitch exec: Data) -> Hitch? { get { return self[hitch: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (halfhitch exec: HalfHitch) -> HalfHitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            return JSValueToHitch(context, resolve(exec))?.halfhitch()
        }
    }
    @inlinable public subscript (halfhitch exec: Hitch) -> HalfHitch? { get { return self[halfhitch: exec.halfhitch()] } }
    @inlinable public subscript (halfhitch exec: String) -> HalfHitch? { get { return self[halfhitch: HalfHitch(string: exec)] } }
    @inlinable public subscript (halfhitch exec: StaticString) -> HalfHitch? { get { return self[halfhitch: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (halfhitch exec: Data) -> HalfHitch? { get { return self[halfhitch: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (string exec: HalfHitch) -> String? {
        get {
            lock.lock(); defer { lock.unlock() }
            return JSValueToHitch(context, resolve(exec))?.toString()
        }
    }
    @inlinable public subscript (string exec: Hitch) -> String? { get { return self[string: exec.halfhitch()] } }
    @inlinable public subscript (string exec: String) -> String? { get { return self[string: HalfHitch(string: exec)] } }
    @inlinable public subscript (string exec: StaticString) -> String? { get { return self[string: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (string exec: Data) -> String? { get { return self[string: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (date exec: HalfHitch) -> Date? {
        get {
            guard let value = self[hitch: exec] else { return nil }
            return value.toString().date()
        }
    }
    @inlinable public subscript (date exec: Hitch) -> Date? { get { return self[date: exec.halfhitch()] } }
    @inlinable public subscript (date exec: String) -> Date? { get { return self[date: HalfHitch(string: exec)] } }
    @inlinable public subscript (date exec: StaticString) -> Date? { get { return self[date: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (date exec: Data) -> Date? { get { return self[date: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (double exec: HalfHitch) -> Double? {
        get {
            lock.lock(); defer { lock.unlock() }
            return JSValueToDouble(context, resolve(exec))
        }
    }
    @inlinable public subscript (double exec: Hitch) -> Double? { get { return self[double: exec.halfhitch()] } }
    @inlinable public subscript (double exec: String) -> Double? { get { return self[double: HalfHitch(string: exec)] } }
    @inlinable public subscript (double exec: StaticString) -> Double? { get { return self[double: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (double exec: Data) -> Double? { get { return self[double: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (int exec: HalfHitch) -> Int? {
        get {
            lock.lock(); defer { lock.unlock() }
            return JSValueToInt(context, resolve(exec))
        }
    }
    @inlinable public subscript (int exec: Hitch) -> Int? { get { return self[int: exec.halfhitch()] } }
    @inlinable public subscript (int exec: String) -> Int? { get { return self[int: HalfHitch(string: exec)] } }
    @inlinable public subscript (int exec: StaticString) -> Int? { get { return self[int: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (int exec: Data) -> Int? { get { return self[int: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (bool exec: HalfHitch) -> Bool? {
        get {
            lock.lock(); defer { lock.unlock() }
            return JSValueToBool(context, resolve(exec))
        }
    }
    @inlinable public subscript (bool exec: Hitch) -> Bool? { get { return self[bool: exec.halfhitch()] } }
    @inlinable public subscript (bool exec: String) -> Bool? { get { return self[bool: HalfHitch(string: exec)] } }
    @inlinable public subscript (bool exec: StaticString) -> Bool? { get { return self[bool: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (bool exec: Data) -> Bool? { get { return self[bool: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (json exec: HalfHitch) -> Hitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            return JSValueToJson(context, resolve(exec))
        }
    }
    @inlinable public subscript (json exec: Hitch) -> Hitch? { get { return self[json: exec.halfhitch()] } }
    @inlinable public subscript (json exec: String) -> Hitch? { get { return self[json: HalfHitch(string: exec)] } }
    @inlinable public subscript (json exec: StaticString) -> Hitch? { get { return self[json: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (json exec: Data) -> Hitch? { get { return self[json: HalfHitch(data: exec)] } }
    
    @discardableResult
    @inlinable
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
        
        // JavascriptCore does not appear to evaluate object literals "{}" correctly, it will
        // always return undefined unless it is embedded in parens first "({})". So as a
        // last attempt try evaluating it embedded in parens
        let modifiedHitch = "({0})" << [hitch]
        if let returnValue: JSValueRef? = modifiedHitch.jsString({ jsScript in
            defer { JSStringRelease(jsScript) }

            var jsException: JSObjectRef? = nil
            let jsValue = JSEvaluateScript(context, jsScript, nil, nil, 0, &jsException)
            if jsException == nil && jsValue != nil && JSValueIsUndefined(context, jsValue) == false {
                return jsValue
            }
            return nil
        }) {
            return returnValue
        }
        
        // if that fails, attempt to resolve using the unmodified string
        if let returnValue: JSValueRef? = hitch.jsString({ jsScript in
            // JavascriptCore does not appear to evaluate object literals "{}" correctly, it will
            // always return undefined unless it is embedded in parens first "({})"
            defer { JSStringRelease(jsScript) }

            var jsException: JSObjectRef? = nil
            let jsValue = JSEvaluateScript(context, jsScript, nil, nil, 0, &jsException)
            if let jsException = jsException {
                // print("resolve exception for: \(hitch)")
                return record(exception: jsException)
            }
            
            if jsValue != nil {
                return jsValue
            }
            return nil
        }) {
            return returnValue
        }
        
        return undefined
    }
    
    @discardableResult
    @inlinable
    func record<T>(exception jsException: JSObjectRef) -> T? {
        self.exception = JSValueToHitch(context, jsException)
        // print(exception ?? "unknown exception occurred")
        return nil
    }
}
