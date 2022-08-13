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
    
    deinit {
        unregisterCallback(callbackID: myCallbackId)
    }
    
    @usableFromInline
    init?(jib: Jib, name: HalfHitch) {
        guard let jsString = CreateJSString(halfhitch: name) else { return nil }
        let value = JSObjectGetProperty(jib.context, jib.global, jsString, nil)
        JSStringRelease(jsString)
        guard JSObjectIsFunction(jib.context, value) else { return nil }
        objectRef = value
        myCallbackId = -1
    }
    
    @usableFromInline
    init?(jib: Jib, name: HalfHitch, body: @escaping JibFunctionBody) {
        
        myCallbackId = registerCallback(body: body)
        
        let functionName = CreateJSString(halfhitch: name)
        JSStringRelease(functionName)
        
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
                            JSValueToHitch(context, argument)
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
    }
}

extension JibFunction: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        guard let objectRef = objectRef else { return JSValueMakeUndefined(context) }
        return objectRef
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

