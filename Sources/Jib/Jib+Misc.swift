import QuickJS
import Hitch
import Foundation

public typealias JibValue = JSValue

let undefinedHitch: Hitch = "undefined"

@inlinable
public func JSValueToJson(_ context: OpaquePointer, _ value: JSValue?) -> Hitch? {
    guard let value = value else { return nil }
    guard JS_IsUndefined(value) == 0 else { return nil }
    let json = JS_JSONStringify(context, value, JS_NewUndefined(context), JS_NewUndefined(context))
    defer { JS_FreeValue(context, json) }
    
    var hitch: Hitch? = nil
    if let utf8 = JS_ToCString(context, json) {
        hitch = Hitch(utf8: utf8)
        JS_FreeCString(context, utf8)
    }
    return hitch
}

@inlinable
func JSValueToHitch(_ context: OpaquePointer, _ value: JSValue?) -> Hitch? {
    guard let value = value else { return nil }
    guard JS_IsUndefined(value) == 0 else { return nil }
    var hitch: Hitch? = nil
    if let utf8 = JS_ToCString(context, value) {
        hitch = Hitch(utf8: utf8)
        JS_FreeCString(context, utf8)
    }
    return hitch
}

@inlinable
public func JSValueToDecodable<T: Decodable>(_ context: OpaquePointer, _ value: JSValue?) -> T? {
    guard let value = value else { return nil }
    guard JS_IsUndefined(value) == 0 else { return nil }
    guard let json = JSValueToJson(context, value) else { return nil }
    return try? JSONDecoder().decode(T.self, from: json.dataNoCopy())
}

@inlinable
public func JSValueToFunction(_ context: OpaquePointer, _ value: JSValue?) -> JibFunction? {
    guard let value = value else { return nil }
    guard JS_IsUndefined(value) == 0 else { return nil }
    guard JS_IsFunction(context, value) != 0 else { return nil }
    return JibFunction(context: context, value: value)
}

@inlinable
public func JSValueToDouble(_ context: OpaquePointer, _ value: JSValue?) -> Double? {
    guard let value = value else { return nil }
    guard JS_IsUndefined(value) == 0 else { return nil }
    guard JS_IsNumber(value) != 0 else { return nil }
    var result: Double = 0
    JS_ToFloat64(context, &result, value)
    return result
}

@inlinable
public func JSValueToInt(_ context: OpaquePointer, _ value: JSValue?) -> Int? {
    guard let value = value else { return nil }
    guard JS_IsUndefined(value) == 0 else { return nil }
    guard JS_IsNumber(value) != 0 else { return nil }
    var result: Int64 = 0
    JS_ToInt64(context, &result, value)
    return Int(result)
}


@inlinable
public func JSValueToBool(_ context: OpaquePointer, _ value: JSValue?) -> Bool? {
    guard let value = value else { return nil }
    guard JS_IsUndefined(value) == 0 else { return nil }
    guard JS_IsBool(value) != 0 else { return nil }
    return JS_ToBool(context, value) != 0
}
