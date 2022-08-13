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
    
    // MARK: - JS Resolution
    
    @inlinable @inline(__always)
    public subscript (eval exec: HalfHitch) -> Bool? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let _ = resolve(exec) else { return nil }
            return true
        }
    }
    
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
    
    @inlinable @inline(__always)
    public subscript (hitch exec: HalfHitch) -> Hitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let value = resolve(exec) else { return nil }
            return JSValueToHitch(context, value)
        }
    }
    
    @inlinable @inline(__always)
    public subscript (halfhitch exec: HalfHitch) -> HalfHitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let value = resolve(exec) else { return nil }
            return JSValueToHitch(context, value).halfhitch()
        }
    }
    
    @inlinable @inline(__always)
    public subscript (string exec: HalfHitch) -> String? {
        get {
            lock.lock(); defer { lock.unlock() }
            
            guard let value = resolve(exec) else { return nil }
            return JSValueToHitch(context, value).description
        }
    }
    
    @inlinable @inline(__always)
    public subscript (date exec: HalfHitch) -> Date? {
        get {
            guard let value = self[hitch: exec] else { return nil }
            return value.description.date()
        }
    }
    
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
    
    @inlinable @inline(__always)
    public subscript (int exec: HalfHitch) -> Int? {
        get {
            guard let number = self[double: exec] else { return nil }
            return Int(number)
        }
    }
    
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
        guard let raw = hitch.raw() else { return undefined }
        
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
