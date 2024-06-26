import CQuickJS
import Hitch

typealias HitchArray = [Hitch]

public protocol JibUnknown {
    func createJibValue(_ jib: Jib) -> JibValue
    func createJibValue(_ context: OpaquePointer) -> JibValue
}

extension JibFunction: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        return JS_DupValue(context, functionValueRef)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return JS_DupValue(jib.context, functionValueRef)
    }
}

extension HitchArray: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        var args = map { $0.createJibValue(context) }
        let array = JS_NewArray(context)
        
        JS_ArrayPush(context, array,
                     Int32(args.count),
                     &args,
                     0)
        
        args.forEach { JS_FreeValue(context, $0) }
        
        return array
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension String: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        let hh = HalfHitch(string: self)
        return JS_NewStringLen(context, hh.raw(), hh.count)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension StaticString: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        let hh = HalfHitch(stringLiteral: self)
        return JS_NewStringLen(context, hh.raw(), hh.count)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Hitch: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        return JS_NewStringLen(context, raw(), count)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension HalfHitch: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        return JS_NewStringLen(context, raw(), count)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Int: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        return JS_NewInt64(context, Int64(self))
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension UInt: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        return JS_NewBigUint64(context, UInt64(self))
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Double: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        return JS_NewFloat64(context, Double(self))
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Float: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        return JS_NewFloat64(context, Double(self))
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Bool: JibUnknown {
    @inlinable
    public func createJibValue(_ context: OpaquePointer) -> JibValue {
        return JS_NewBool(context, self ? 1 : 0)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return self ? jib.true : jib.false
    }
}

