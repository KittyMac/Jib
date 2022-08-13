#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

private let callbacksLock = NSLock()
private var callbacksShared: [Int: JibFunctionBody] = [:]
private var callbacksID: Int = 0

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
                
        let jsValue = JSObjectCallAsFunction(context, function, nil, convertedArgs.count, convertedArgs, &jsException)
        
        if let jsException = jsException {
            throw RuntimeError(JSValueToHitch(context, jsException))
        }
                
        return JSValueToHitch(context, jsValue)
    }
    
    public func garbageCollect() {
        JSGarbageCollect(context)
    }
    
    public func function(name: HalfHitch, body: @escaping JibFunctionBody) -> JibFunction {
        
        callbacksLock.lock()
        
        let myCallbackId = callbacksID
        callbacksID += 1
        
        callbacksShared[myCallbackId] = body
        callbacksLock.unlock()
                
        let functionObject = JSObjectMakeFunctionWithCallback(context, HalfHitchToJSString(context, name)) { context, function, thisObject, argumentCount, arguments, exception in
            callbacksLock.lock(); defer { callbacksLock.unlock() }
            
            if let context = context {
                let myCallbackIdValue = JSObjectGetProperty(context, function, HalfHitchToJSString(context, "uuid"), nil)
                let myCallbackId = Int(JSValueToNumber(context, myCallbackIdValue, nil))
                
                if let callback = callbacksShared[myCallbackId] {
                    let result = callback([])
                }
                
                callbacksShared.removeValue(forKey: myCallbackId)
            }

            
            return nil
        }
        
        guard let functionObject = functionObject else {
            return undefined
        }
                
        JSObjectSetProperty(context, functionObject, HalfHitchToJSString(context, "uuid"), myCallbackId.createJibValue(self), 0, nil)
        
        return functionObject
    }
    
    @inlinable @inline(__always)
    public subscript (function name: HalfHitch) -> JibFunction? {
        get {
            guard let hitch = HalfHitchToJSString(context, name) else { return nil }
            let value = JSObjectGetProperty(context, global, hitch, nil)
            guard JSObjectIsFunction(context, value) else { return nil }
            return value
        }
    }
    
    
}
