import QuickJS
import Hitch

public typealias JibFunctionBody = ([Hitch]) -> Any?

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
    func run(parameters: [Hitch]) -> Any? {
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
    //@usableFromInline
    //let jsClass: JSClassRef
    
    @usableFromInline
    let functionValueRef: JSValue?
    
    @usableFromInline
    let bodyPtr: AnyPtr
    
    var context: OpaquePointer
    
    deinit {
        let _: JibBody? = MakeReleasedClass(bodyPtr)
        
        if let functionValueRef = functionValueRef {
            JS_FreeValue(context, functionValueRef)
        }
    }
    
    @usableFromInline
    init?(context: OpaquePointer, object: JSValue) {
        self.context = context
        functionValueRef = object
        bodyPtr = nil
    }
    
    @usableFromInline
    init?(jib: Jib, name: HalfHitch, body: @escaping JibFunctionBody) {
        context = jib.context
        
        bodyPtr = MakeRetainedPtr(JibBody(body))
        
        functionValueRef = JS_NewCFunctionMagic(jib.context, { ctx, this, argc, argv, magic in
            guard let ctx = ctx else { return JS_NewUndefined(ctx) }
            let bodyPtr = UnsafeMutableRawPointer(bitPattern: UInt(magic))
            
            if let jibBody: JibBody = MakeRetainedClass(bodyPtr) {
                var parameters: [Hitch] = []
                
                for idx in 0..<Int(argc) {
                    guard let argument = argv?[idx] else { continue }
                    parameters.append(
                        JSValueToHitch(ctx, argument) ?? undefinedHitch
                    )
                }
                
                let result = jibBody.run(parameters: parameters)
                
                //return result?.createJibValue(context)
            }

            return JS_NewUndefined(ctx)
        }, name.raw(), Int32(name.count), JS_CFUNC_generic_magic, UInt64(UInt(bitPattern: bodyPtr)))
    }
}


/*

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
        
        if let jib = jib {
            JSValueUnprotect(jib.context, objectRef)
        }
    }
    
    @usableFromInline
    init?(jib: Jib, object: JSObjectRef) {
        self.jib = jib

        objectRef = object
        
        self.bodyPtr = JSObjectGetPrivate(objectRef)
        
        JSValueProtect(jib.context, objectRef)
        
        var classDefinition = kJSClassDefinitionEmpty
        jsClass = JSClassCreate(&classDefinition)
    }
    
    @usableFromInline
    init?(jib: Jib, name: HalfHitch, body: @escaping JibFunctionBody) {
        self.jib = jib
        
        var classDefinition = kJSClassDefinitionEmpty
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

*/
