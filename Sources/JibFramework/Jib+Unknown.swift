#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

public protocol JibUnknown {
    func createJibValue(_ jib: Jib) -> JibValue
}

extension JibFunction: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return self
    }
}

extension String: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        let hh = HalfHitch(string: self)
        guard let raw = hh.raw() else { return jib.undefined }
        guard let jsString = JSStringCreateWithUTF8CString(raw) else { return jib.undefined }
        defer { JSStringRelease(jsString) }
        return JSValueMakeString(jib.context, jsString)
    }
}

extension StaticString: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        let hh = HalfHitch(stringLiteral: self)
        guard let raw = hh.raw() else { return jib.undefined }
        guard let jsString = JSStringCreateWithUTF8CString(raw) else { return jib.undefined }
        defer { JSStringRelease(jsString) }
        return JSValueMakeString(jib.context, jsString)
    }
}

extension Hitch: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        let hh = halfhitch()
        guard let raw = hh.raw() else { return jib.undefined }
        guard let jsString = JSStringCreateWithUTF8CString(raw) else { return jib.undefined }
        defer { JSStringRelease(jsString) }
        return JSValueMakeString(jib.context, jsString)
    }
}

extension HalfHitch: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        guard let raw = raw() else { return jib.undefined }
        guard let jsString = JSStringCreateWithUTF8CString(raw) else { return jib.undefined }
        defer { JSStringRelease(jsString) }
        return JSValueMakeString(jib.context, jsString)
    }
}

extension Int: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return JSValueMakeNumber(jib.context, Double(self))
    }
}

extension UInt: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return JSValueMakeNumber(jib.context, Double(self))
    }
}

extension Double: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return JSValueMakeNumber(jib.context, self)
    }
}

extension Float: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return JSValueMakeNumber(jib.context, Double(self))
    }
}

extension Bool: JibUnknown {
    @inlinable @inline(__always)
    public func createJibValue(_ jib: Jib) -> JibValue {
        return self ? jib.true : jib.false
    }
}
