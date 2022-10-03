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
private let callbacksProperyName = CreateJSString(halfhitch: "__uuid")

private func registerCallback(body: @escaping JibFunctionBody) -> Int {
    callbacksLock.lock(); defer { callbacksLock.unlock() }
    
    callbacksID += 1
    
    let myCallbackId = callbacksID
    callbacksShared[myCallbackId] = body
    
    return myCallbackId
}

private func unregisterCallback(callbackID: Int) {
    callbacksLock.lock()
    callbacksShared.removeValue(forKey: callbackID)
    callbacksLock.unlock()
}

public typealias JibFunctionBody = ([Hitch]) -> JibUnknown?

public class JibFunction {
    let myCallbackId: Int
    
    @usableFromInline
    let objectRef: JSObjectRef?
    
    weak var jib: Jib?
    
    deinit {
        if let jib = jib {
            JSValueUnprotect(jib.context, objectRef)
        }
        
        unregisterCallback(callbackID: myCallbackId)
    }
    
    @usableFromInline
    init?(jib: Jib, object: JSObjectRef) {
        self.jib = jib
        
        objectRef = object
        myCallbackId = -1
        
        JSValueProtect(jib.context, objectRef)
    }
    
    @usableFromInline
    init?(jib: Jib, name: HalfHitch, body: @escaping JibFunctionBody) {
        self.jib = jib
        
        myCallbackId = registerCallback(body: body)
        
        let functionName = CreateJSString(halfhitch: name)
        defer { JSStringRelease(functionName) }
        
        objectRef = JSObjectMakeFunctionWithCallback(jib.context, functionName) { context, function, thisObject, argumentCount, arguments, exception in
            callbacksLock.lock(); defer { callbacksLock.unlock() }
            
            if let context = context {
                let myCallbackIdValue = JSObjectGetProperty(context, function, callbacksProperyName, nil)
                let myCallbackId = Int(JSValueToNumber(context, myCallbackIdValue, nil))
                
                if let callback = callbacksShared[myCallbackId] {
                    var parameters: [Hitch] = []
                    
                    for idx in 0..<argumentCount {
                        guard let argument = arguments?[idx] else { continue }
                        parameters.append(
                            JSValueToHitch(context, argument) ?? undefinedHitch
                        )
                    }
                    
                    let result = callback(parameters)
                    
                    return result?.createJibValue(context)
                }
            }

            return nil
        }
        
        guard let objectRef = objectRef else {
            return nil
        }
        
        JSObjectSetProperty(jib.context, objectRef, callbacksProperyName, myCallbackId.createJibValue(jib), 0, nil)
        
        JSValueProtect(jib.context, objectRef)
    }
}

extension JibFunction: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        guard let objectRef = objectRef else {
            print("FAILED TO CREATE JSVALUE FROM \(self)")
            return JSValueMakeUndefined(context)
        }
        return objectRef
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

