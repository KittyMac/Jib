#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

typealias HitchArray = [Hitch]

public protocol JibUnknown {
    func createJibValue(_ jib: Jib) -> JibValue
    func createJibValue(_ context: JSGlobalContextRef) -> JibValue
}
/*
extension JibFunction: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return self
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return self
    }
}
*/
extension HitchArray: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        let args = map { HalfHitchToJSValue(context, $0.halfhitch()) }
        return JSObjectMakeArray(context, args.count, args, nil)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension String: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        guard let jsString = HalfHitch(string: self).using({ bytes in
            return JSStringCreateWithUTF8CString(bytes)
        }) else {
            return JSValueMakeUndefined(context)
        }
        
        defer { JSStringRelease(jsString) }
        return JSValueMakeString(context, jsString)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension StaticString: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        guard let jsString = HalfHitch(stringLiteral: self).using({ bytes in
            return JSStringCreateWithUTF8CString(bytes)
        }) else {
            return JSValueMakeUndefined(context)
        }
        
        defer { JSStringRelease(jsString) }
        return JSValueMakeString(context, jsString)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Hitch: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        guard let jsString = halfhitch().using({ bytes in
            return JSStringCreateWithUTF8CString(bytes)
        }) else {
            return JSValueMakeUndefined(context)
        }
        
        defer { JSStringRelease(jsString) }
        return JSValueMakeString(context, jsString)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension HalfHitch: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        guard let raw = raw() else {
            return JSValueMakeUndefined(context)
        }
        guard let jsString = JSStringCreateWithUTF8CString(raw) else {
            return JSValueMakeUndefined(context)
        }
        defer { JSStringRelease(jsString) }
        return JSValueMakeString(context, jsString)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Int: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeNumber(context, Double(self))
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension UInt: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeNumber(context, Double(self))
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Double: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeNumber(context, self)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Float: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeNumber(context, Double(self))
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Bool: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeBoolean(context, self)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return self ? jib.true : jib.false
    }
}

