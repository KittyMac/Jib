#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

public typealias JibFunction = JSObjectRef
public typealias JibValue = JSValueRef

@usableFromInline
let undefinedHitch: Hitch = "undefined"

extension JibValue {
    
}

@inlinable @inline(__always)
func JSStringToHitch(_ context: JSGlobalContextRef, _ jsString: JSStringRef?) -> Hitch {
    guard let jsString = jsString else { return undefinedHitch }
    let size = JSStringGetMaximumUTF8CStringSize(jsString)
    let result = Hitch(garbage: size)
    guard let raw = result.mutableRaw() else { return undefinedHitch }
    result.count = JSStringGetUTF8CString(jsString, raw, size) - 1
    return result
}

@inlinable @inline(__always)
func JSValueToHitch(_ context: JSGlobalContextRef, _ value: JSValueRef?) -> Hitch {
    guard let value = value else { return undefinedHitch }
    let jsString = JSValueToStringCopy(context, value, nil)
    defer { JSStringRelease(jsString) }
    return JSStringToHitch(context, jsString)
}

@inlinable @inline(__always)
func HalfHitchToJSString(_ context: JSGlobalContextRef, _ value: HalfHitch) -> JSStringRef? {
    guard let raw = value.raw() else { return nil }
    return JSStringCreateWithUTF8CString(raw)
}

@inlinable @inline(__always)
public func JSValueToJson(_ context: JSGlobalContextRef, _ value: JSObjectRef?) -> Hitch {
    let jsString = JSValueCreateJSONString(context, value, 2, nil)
    defer { JSStringRelease(jsString) }
    return JSStringToHitch(context, jsString)
}
