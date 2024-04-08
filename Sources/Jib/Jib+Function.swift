import QuickJS
import Hitch

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
    let functionValueRef: JSValue
    
    @usableFromInline
    let bodyPtr: AnyPtr
    
    var context: OpaquePointer
    
    deinit {
        let _: JibBody? = MakeReleasedClass(bodyPtr)
    }
    
    @usableFromInline
    init?(context: OpaquePointer, value: JSValue) {
        self.context = context
        functionValueRef = JS_DupValue(context, value)
        bodyPtr = nil
    }
    
    @usableFromInline
    init?(jib: Jib, name: HalfHitch, body: @escaping JibFunctionBody) {
        context = jib.context
        
        bodyPtr = MakeRetainedPtr(JibBody(body))
        
        let functionValue = JS_NewCFunctionMagic(jib.context, { ctx, this, argc, argv, magic in
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
                
                if let result = jibBody.run(parameters: parameters) {
                    return result.createJibValue(ctx)
                }
                return JS_NewUndefined(ctx)
            }

            return JS_NewUndefined(ctx)
        }, name.raw(), Int32(name.count), JS_CFUNC_generic_magic, UInt64(UInt(bitPattern: bodyPtr)))
                
        functionValueRef = JS_DupValue(context, functionValue)
    }
}
