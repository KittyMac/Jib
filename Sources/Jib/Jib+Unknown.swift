#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch
import Spanker

typealias HitchArray = [Hitch]

public protocol JibUnknown {
    func createJibValue(_ jib: Jib) -> JibValue
    func createJibValue(_ context: JSGlobalContextRef) -> JibValue
}
/*
extension JibFunction: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return self
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return self
    }
}
*/
extension HitchArray: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        let args = map { HalfHitchToJSValue(context, $0.halfhitch()) }
        print("CREATING JSVALUE FROM HITCHARRAY \(self)")
        return JSObjectMakeArray(context, args.count, args, nil)
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension String: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        
        let hh = HalfHitch(string: self)
        if let raw = hh.raw() {
            print(hh.count)
            let jsString = JSStringCreateWithUTF8CString(raw)
            defer { JSStringRelease(jsString) }
            print(hh.count)
            return JSValueMakeString(context, jsString)
        }
        
        print(hh.count)
        
        print("FAILED TO CREATE JSVALUE FROM \(self)")
        return JSValueMakeUndefined(context)
        
        /*
        guard let jsString = self.withCString({ bytes in
            return JSStringCreateWithUTF8CString(bytes)
        }) else {
            print("FAILED TO CREATE JSVALUE FROM \(self)")
            return JSValueMakeUndefined(context)
        }
        
        defer { JSStringRelease(jsString) }
        return JSValueMakeString(context, jsString)
         */
        
        /*
        let jsString = self.withUTF8 { bytes in
            return JSStringCreateWithUTF8CString(bytes)
        }
        */
        /*
        let hh = HalfHitch(string: self)
        guard let raw = hh.raw() else {
            print("FAILED TO CREATE JSVALUE FROM \(self)")
            return JSValueMakeUndefined(context)
        }
        guard let jsString = JSStringCreateWithUTF8CString(raw) else {
            print("FAILED TO CREATE JSVALUE FROM \(self)")
            return JSValueMakeUndefined(context)
        }
        //defer { print("CALLING DEFER"); JSStringRelease(jsString) }
        //print("1 CREATING JSVALUE FROM STRING \(self)")
        //print("2 CREATING JSVALUE FROM STRING \(hh)")
        print("3 CREATING JSVALUE FROM STRING \(JSStringToHitch(context, jsString))")
        let val = JSValueMakeString(context, jsString)
        print("4 CREATING JSVALUE FROM STRING \(JSValueToHitch(context, val))")
        return val!*/
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension StaticString: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        let hh = HalfHitch(stringLiteral: self)
        guard let raw = hh.raw() else {
            print("FAILED TO CREATE JSVALUE FROM \(self)")
            return JSValueMakeUndefined(context)
        }
        guard let jsString = JSStringCreateWithUTF8CString(raw) else {
            print("FAILED TO CREATE JSVALUE FROM \(self)")
            return JSValueMakeUndefined(context)
        }
        defer { JSStringRelease(jsString) }
        print("CREATING JSVALUE FROM STATICSTRING \(self)")
        return JSValueMakeString(context, jsString)
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Hitch: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        let hh = halfhitch()
        guard let raw = hh.raw() else {
            print("FAILED TO CREATE JSVALUE FROM \(self)")
            return JSValueMakeUndefined(context)
        }
        guard let jsString = JSStringCreateWithUTF8CString(raw) else {
            print("FAILED TO CREATE JSVALUE FROM \(self)")
            return JSValueMakeUndefined(context)
        }
        defer { JSStringRelease(jsString) }
        print("CREATING JSVALUE FROM HITCH \(self)")
        return JSValueMakeString(context, jsString)
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension HalfHitch: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        guard let raw = raw() else {
            print("FAILED TO CREATE JSVALUE FROM \(self)")
            return JSValueMakeUndefined(context)
        }
        guard let jsString = JSStringCreateWithUTF8CString(raw) else {
            print("FAILED TO CREATE JSVALUE FROM \(self)")
            return JSValueMakeUndefined(context)
        }
        defer { JSStringRelease(jsString) }
        print("CREATING JSVALUE FROM HalfHitch\(self)")
        return JSValueMakeString(context, jsString)
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Int: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeNumber(context, Double(self))
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension UInt: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeNumber(context, Double(self))
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Double: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeNumber(context, self)
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Float: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeNumber(context, Double(self))
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

extension Bool: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeBoolean(context, self)
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return self ? jib.true : jib.false
    }
}

/*
extension HitchArray: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        let hitchJson = JsonElement(unknown: self.map { JsonElement(unknown: $0) } ).toHitch().halfhitch()
        return JSValueMakeFromJSONString(context, HalfHitchToJSString(context, hitchJson))
    }
    
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}
*/
