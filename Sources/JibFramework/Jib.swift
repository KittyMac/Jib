#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

public class Jib {
    public let context: JSGlobalContextRef
    public let group: JSContextGroupRef
    public let global: JSObjectRef
    public let undefined: JSObjectRef
    public let `true`: JSObjectRef
    public let `false`: JSObjectRef
    
    deinit {
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
    public func exec(_ script: HalfHitch) throws -> Hitch? {
        guard let raw = script.raw() else { return nil }
        
        let jsScript = JSStringCreateWithUTF8CString(raw)
        var jsException: JSObjectRef? = nil
        
        let jsValue = JSEvaluateScript(context, jsScript, nil, nil, 0, &jsException)
        
        JSStringRelease(jsScript)
        
        if let jsException = jsException {
            throw RuntimeError(JSValueToHitch(context, jsException))
        }
                
        return JSValueToHitch(context, jsValue)
    }
    
    @discardableResult
    public func call(_ function: JibFunction, _ args: [JibUnknown?]) throws -> Hitch? {
        var jsException: JSObjectRef? = nil
        
        let convertedArgs = args.map { $0?.createJibValue(self) }
                
        let jsValue = JSObjectCallAsFunction(context, function.objectRef, nil, convertedArgs.count, convertedArgs, &jsException)
        
        if let jsException = jsException {
            throw RuntimeError(JSValueToHitch(context, jsException))
        }
                
        return JSValueToHitch(context, jsValue)
    }
    
    public func garbageCollect() {
        JSGarbageCollect(context)
    }
    
    @discardableResult
    public func makeFunction(name: HalfHitch, body: @escaping JibFunctionBody) -> JibFunction? {
        return JibFunction(jib: self, name: name, body: body)
    }
    
    @inlinable @inline(__always)
    public subscript (function name: HalfHitch) -> JibFunction? {
        get {
            return JibFunction(jib: self, name: name)
        }
    }
    
    
}
