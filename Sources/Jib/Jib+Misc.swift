#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

public typealias JibValue = JSValueRef

@usableFromInline
let undefinedHitch: Hitch = "undefined"

extension JibValue {
    
}

@inlinable
func JSStringToHitch(_ context: JSGlobalContextRef, _ jsString: JSStringRef?) -> Hitch {
    guard let jsString = jsString else { return undefinedHitch }
    let size = JSStringGetMaximumUTF8CStringSize(jsString)
    let result = Hitch(garbage: size)
    if let returnValue: Hitch = result.mutableUsing({ mutableRaw, count in
        result.count = JSStringGetUTF8CString(jsString, mutableRaw, size) - 1
        return result
    }) {
        return returnValue
    }
    return undefinedHitch
}

@inlinable
func CreateJSString(halfhitch value: HalfHitch) -> JSStringRef? {
    return value.jsString { jsString in
        return jsString
    }
}

@inlinable
func HalfHitchToJSValue(_ context: JSGlobalContextRef, _ value: HalfHitch) -> JSStringRef? {
    return value.jsString { jsString in
        defer { JSStringRelease(jsString) }
        guard let result = JSValueMakeString(context, jsString) else {
            return nil
        }
        return result
    }
}

@inlinable
public func JSValueToJson(_ context: JSGlobalContextRef, _ value: JSObjectRef?) -> Hitch? {
    guard let value = value else { return nil }
    guard let jsString = JSValueCreateJSONString(context, value, 0, nil) else { return nil }
    let result = JSStringToHitch(context, jsString)
    JSStringRelease(jsString)
    return result
}

@inlinable
func JSValueToHitch(_ context: JSGlobalContextRef, _ value: JSValueRef?) -> Hitch? {
    guard let value = value else { return nil }
    let jsString = JSValueToStringCopy(context, value, nil)
    let result = JSStringToHitch(context, jsString)
    JSStringRelease(jsString)
    return result
}

@inlinable
public func JSValueToDecodable<T: Decodable>(_ context: JSGlobalContextRef, _ value: JSValueRef?) -> T? {
    guard let value = value else { return nil }
    guard JSValueIsUndefined(context, value) == false else { return nil }
    guard let json = JSValueToJson(context, value) else { return nil }
    return try? JSONDecoder().decode(T.self, from: json.dataNoCopy())
}

@inlinable
public func JSValueToFunction(_ jib: Jib, _ value: JSValueRef?) -> JibFunction? {
    guard let value = value else { return nil }
    guard JSValueIsUndefined(jib.context, value) == false else { return nil }
    guard JSObjectIsFunction(jib.context, value) == true else { return nil }
    return JibFunction(jib: jib, object: value)
}

@inlinable
public func JSValueToDouble(_ context: JSGlobalContextRef, _ value: JSValueRef?) -> Double? {
    guard let value = value else { return nil }
    guard JSValueIsUndefined(context, value) == false else { return nil }
    guard JSValueIsNumber(context, value) == true else { return nil }
    return JSValueToNumber(context, value, nil)
}

@inlinable
public func JSValueToInt(_ context: JSGlobalContextRef, _ value: JSValueRef?) -> Int? {
    guard let value = value else { return nil }
    guard JSValueIsUndefined(context, value) == false else { return nil }
    guard JSValueIsNumber(context, value) == true else { return nil }
    return Int(JSValueToNumber(context, value, nil))
}

@inlinable
public func JSValueToBool(_ context: JSGlobalContextRef, _ value: JSValueRef?) -> Bool? {
    guard let value = value else { return nil }
    guard JSValueIsUndefined(context, value) == false else { return nil }
    guard JSValueIsBoolean(context, value) == true else { return nil }
    return JSValueToBoolean(context, value)
}




