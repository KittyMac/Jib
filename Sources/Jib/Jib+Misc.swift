import QuickJS
import Hitch
import Foundation

/*

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif
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
*/

@inlinable
public func JSValueToJson(_ context: OpaquePointer, _ value: JSValue) -> Hitch? {
    guard JS_IsObject(value) != 0 else { return nil }
    let json = JS_JSONStringify(context, value, JS_NewUndefined(context), JS_NewUndefined(context))
    var hitch: Hitch? = nil
    if let utf8 = JS_ToCString(context, json) {
        hitch = Hitch(utf8: utf8)
        JS_FreeCString(context, utf8)
    }
    return hitch
}

@inlinable
func JSValueToHitch(_ context: OpaquePointer, _ value: JSValue) -> Hitch? {
    guard JS_IsString(value) != 0 else { return nil }
    var hitch: Hitch? = nil
    if let utf8 = JS_ToCString(context, value) {
        hitch = Hitch(utf8: utf8)
        JS_FreeCString(context, utf8)
    }
    return hitch
}

@inlinable
public func JSValueToDecodable<T: Decodable>(_ context: OpaquePointer, _ value: JSValue) -> T? {
    guard JS_IsUndefined(value) == 0 else { return nil }
    guard let json = JSValueToJson(context, value) else { return nil }
    return try? JSONDecoder().decode(T.self, from: json.dataNoCopy())
}
/*
@inlinable
public func JSValueToFunction(_ jib: Jib, _ value: JSValueRef?) -> JibFunction? {
    guard let value = value else { return nil }
    guard JSValueIsUndefined(jib.context, value) == false else { return nil }
    guard JSObjectIsFunction(jib.context, value) == true else { return nil }
    return JibFunction(jib: jib, object: value)
}
*/
@inlinable
public func JSValueToDouble(_ context: OpaquePointer, _ value: JSValue) -> Double? {
    guard JS_IsNumber(value) != 0 else { return nil }
    var result: Double = 0
    JS_ToFloat64(context, &result, value)
    return result
}

@inlinable
public func JSValueToInt(_ context: OpaquePointer, _ value: JSValue) -> Int? {
    guard JS_IsNumber(value) != 0 else { return nil }
    var result: Int64 = 0
    JS_ToInt64(context, &result, value)
    return Int(result)
}


@inlinable
public func JSValueToBool(_ context: OpaquePointer, _ value: JSValue) -> Bool? {
    guard JS_IsBool(value) != 0 else { return nil }
    return JS_ToBool(context, value) != 0
}
