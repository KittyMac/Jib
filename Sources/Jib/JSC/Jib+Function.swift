#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

private let jibCallbackProperyName = CreateJSString(halfhitch: "__jib_block")

public typealias JibFunctionBody = ([Hitch]) -> JibUnknown?

@usableFromInline
typealias AnyPtr = UnsafeMutableRawPointer?

@usableFromInline
class JibBody {
    @usableFromInline
    var block: JibFunctionBody?
    
    @usableFromInline
    init(_ block: @escaping JibFunctionBody) {
        self.block = block
    }

    @inlinable
    func set(_ block: @escaping JibFunctionBody) {
        self.block = block
    }

    @inlinable
    func run(parameters: [Hitch]) -> JibUnknown? {
        return block?(parameters)
    }
}

@inlinable
func MakeRetainedPtr <T: AnyObject>(_ obj: T) -> AnyPtr {
    return Unmanaged.passRetained(obj).toOpaque()
}

@inlinable
func MakeRetainedClass <T: AnyObject>(_ ptr: AnyPtr) -> T? {
    guard let ptr = ptr else { return nil }
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}

@inlinable
func MakeReleasedClass <T: AnyObject>(_ ptr: AnyPtr) -> T? {
    guard let ptr = ptr else { return nil }
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}

public class JibFunction {
    @usableFromInline
    let jsClass: JSClassRef
    
    @usableFromInline
    let objectRef: JSObjectRef?
    
    @usableFromInline
    let bodyPtr: AnyPtr
    
    weak var jib: Jib?
    
    deinit {
        let _: JibBody? = MakeReleasedClass(bodyPtr)
        
        JSClassRelease(jsClass)
        
        if let jib = jib,
           jib.released == false {
            JSValueUnprotect(jib.context, objectRef)
        }
    }
    
    @usableFromInline
    init?(jib: Jib, object: JSObjectRef) {
        self.jib = jib

        objectRef = object
        
        self.bodyPtr = JSObjectGetPrivate(objectRef)
        
        JSValueProtect(jib.context, objectRef)
        
        var classDefinition = JSClassDefinition()
        jsClass = JSClassCreate(&classDefinition)
    }
    
    @usableFromInline
    init?(jib: Jib, name: HalfHitch, body: @escaping JibFunctionBody) {
        self.jib = jib
        
        var classDefinition = JSClassDefinition()
        jsClass = JSClassCreate(&classDefinition)
        
        bodyPtr = MakeRetainedPtr(JibBody(body))
        
        let functionName = CreateJSString(halfhitch: name)
        defer { JSStringRelease(functionName) }
        
        objectRef = JSObjectMakeFunctionWithCallback(jib.context, functionName) { context, function, thisObject, argumentCount, arguments, exception in
            if let context = context {
                let myCallbackIdValue = JSObjectGetProperty(context, function, jibCallbackProperyName, nil)
                let bodyPtr = JSObjectGetPrivate(myCallbackIdValue)
                
                if let jibBody: JibBody = MakeRetainedClass(bodyPtr) {
                    var parameters: [Hitch] = []
                    
                    for idx in 0..<argumentCount {
                        guard let argument = arguments?[idx] else { continue }
                        parameters.append(
                            JSValueToHitch(context, argument) ?? undefinedHitch
                        )
                    }
                    
                    let result = jibBody.run(parameters: parameters)
                    
                    return result?.createJibValue(context)
                }
            }

            return nil
        }
        
        guard let objectRef = objectRef else {
            return nil
        }
        
        let bodyObject = JSObjectMake(jib.context, jsClass, bodyPtr)
        
        JSObjectSetProperty(jib.context, objectRef, jibCallbackProperyName, bodyObject, 0, nil)
        
        JSValueProtect(jib.context, objectRef)
    }
}

extension JibFunction: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        guard let objectRef = objectRef else {
            return JSValueMakeUndefined(context)
        }
        return objectRef
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

