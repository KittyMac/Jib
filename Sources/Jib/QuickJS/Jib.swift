import Foundation
import Hitch
import Chronometer

import CQuickJS

/*
 enum {
     /* all tags with a reference count are negative */
     JS_TAG_FIRST       = -11, /* first negative tag */
     JS_TAG_BIG_DECIMAL = -11,
     JS_TAG_BIG_INT     = -10,
     JS_TAG_BIG_FLOAT   = -9,
     JS_TAG_SYMBOL      = -8,
     JS_TAG_STRING      = -7,
     JS_TAG_MODULE      = -3, /* used internally */
     JS_TAG_FUNCTION_BYTECODE = -2, /* used internally */
     JS_TAG_OBJECT      = -1,

     JS_TAG_INT         = 0,
     JS_TAG_BOOL        = 1,
     JS_TAG_NULL        = 2,
     JS_TAG_UNDEFINED   = 3,
     JS_TAG_UNINITIALIZED = 4,
     JS_TAG_CATCH_OFFSET = 5,
     JS_TAG_EXCEPTION   = 6,
     JS_TAG_FLOAT64     = 7,
     /* any larger tag is FLOAT64 if JS_NAN_BOXING */
 };
 */

extension Hitch {
    @usableFromInline
    func nullTerminated<T>(_ callback: (HalfHitch) -> (T?)) -> T? {
        if let mutableRaw = mutableRaw(),
           mutableRaw[count] != 0 {
            mutableRaw[count] = 0
            return callback(halfhitch())
        }
        if let raw = raw(),
           raw[count] != 0 {
            let nulled = Hitch(hitch: self)
            nulled.count = self.count
            nulled[count] = 0
            return callback(nulled.halfhitch())
        }
        return callback(halfhitch())
    }
}

extension HalfHitch {
    @usableFromInline
    func nullTerminated<T>(_ callback: (HalfHitch) -> (T?)) -> T? {
        if let raw = raw(),
           raw[count] != 0 {
            let nulled = hitch()
            nulled.count = self.count
            nulled[count] = 0
            return callback(nulled.halfhitch())
        }
        return callback(self)
    }
}

public class Jib {
    public let runtime: OpaquePointer
    public let context: OpaquePointer
    public let global: JSValue
    
    public let undefined: JSValue
    public let `true`: JSValue
    public let `false`: JSValue

    public var exception: Hitch?
    
    private var customFunctions: [JibFunction] = []
        
    @usableFromInline
    let lock = NSLock()

    
    deinit {
        lock.lock(); defer { lock.unlock() }
        
        customFunctions.forEach { fnc in
            JS_FreeValue(context, fnc.functionValueRef)
        }
        
        JS_FreeContext(context)
        JS_FreeRuntime(runtime)
    }
    
    public init() {
        runtime = JS_NewRuntime()
        context = JS_NewContext(runtime)
        
        undefined = JS_NewUndefined(context)
        `true` = JS_NewBool(context, 1)
        `false` = JS_NewBool(context, 0)
        
        global = JS_GetGlobalObject(context);
        if set(global: "global", value: global) == nil {
            print("warning: jib set global failed")
        }
                        
        if let printFn = new(function: "print", body: { arguments in
            for argument in arguments {
                print(argument)
            }
            return nil
        }) {
            set(global: "print", value: printFn)
            _ = eval("console = {}; console.log = print;")
        } else {
            print("warning: jibPrint failed to be created, console.log will not work")
        }
    }
    
    @discardableResult
    func recordIf(exception: JSValue) -> Bool? {
        guard JS_IsException(exception) != 0 else { return true }
        return recordException()
    }
    
    @discardableResult
    func recordException() -> Bool? {
        let exceptionValue = JS_GetException(context)
        defer { JS_FreeValue(context, exceptionValue) }
        
        var exceptionHitch: Hitch = "Unknown Exception"
        if let utf8 = JS_ToCString(context, exceptionValue) {
            exceptionHitch = Hitch(utf8: utf8)
            JS_FreeCString(context, utf8)
        }
        
        self.exception = exceptionHitch
        return nil
    }
    
    public func garbageCollect() {
        lock.lock(); defer { lock.unlock() }
        JS_RunGC(runtime)
    }
    
    // MARK: - JS Call
    private func call(jsvalue function: JibFunction, _ args: [JibUnknown?]) -> JSValue? {
        var convertedArgs = args.map { ($0?.createJibValue(self)) ?? JS_NewUndefined(context) }
        if args.count != convertedArgs.count {
            self.exception = "jib.call failed to convert all arguments to JSValues"
        }
        
        let result = JS_Call(context,
                             function.functionValueRef,
                             undefined,
                             Int32(convertedArgs.count),
                             &convertedArgs)
        
        convertedArgs.forEach { JS_FreeValue(context, $0) }
        
        guard let _ = recordIf(exception: result) else { return nil }
        return result
    }
    
    public func call<T: Decodable>(decoded function: JibFunction, _ args: [JibUnknown?]) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        let retValue: T? = JSValueToDecodable(context, jsValue)
        JS_FreeValue(context, jsValue)
        return retValue
    }
    public func call(function: JibFunction, _ args: [JibUnknown?]) -> JibFunction? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        let retValue: JibFunction? = JSValueToFunction(context, jsValue)
        JS_FreeValue(context, jsValue)
        return retValue
    }
    public func call(hitch function: JibFunction, _ args: [JibUnknown?]) -> Hitch? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        let retValue: Hitch? = JSValueToHitch(context, jsValue)
        JS_FreeValue(context, jsValue)
        return retValue
    }
    public func call(halfhitch function: JibFunction, _ args: [JibUnknown?]) -> HalfHitch? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        let retValue: Hitch? = JSValueToHitch(context, jsValue)
        JS_FreeValue(context, jsValue)
        return retValue?.halfhitch()
    }
    public func call(string function: JibFunction, _ args: [JibUnknown?]) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        let retValue: Hitch? = JSValueToHitch(context, jsValue)
        JS_FreeValue(context, jsValue)
        return retValue?.toString()
    }
    public func call(date function: JibFunction, _ args: [JibUnknown?]) -> Date? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        let retValue: Hitch? = JSValueToHitch(context, jsValue)
        JS_FreeValue(context, jsValue)
        return retValue?.toString().date()
    }
    public func call(double function: JibFunction, _ args: [JibUnknown?]) -> Double? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        let retValue: Double? = JSValueToDouble(context, jsValue)
        JS_FreeValue(context, jsValue)
        return retValue
    }
    public func call(int function: JibFunction, _ args: [JibUnknown?]) -> Int? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        let retValue: Int? = JSValueToInt(context, jsValue)
        JS_FreeValue(context, jsValue)
        return retValue
    }
    public func call(bool function: JibFunction, _ args: [JibUnknown?]) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        let retValue: Bool? = JSValueToBool(context, jsValue)
        JS_FreeValue(context, jsValue)
        return retValue
    }
    public func call(json function: JibFunction, _ args: [JibUnknown?]) -> Hitch? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        let retValue: Hitch? = JSValueToJson(context, jsValue)
        JS_FreeValue(context, jsValue)
        return retValue
    }
    
    public func call(none function: JibFunction, _ args: [JibUnknown?]) -> Any? {
        lock.lock(); defer { lock.unlock() }
        guard let jsValue = call(jsvalue: function, args) else { return nil }
        JS_FreeValue(context, jsValue)
        return true
    }
    
    // MARK: - JS Evaluation
    @discardableResult
    public func eval(_ script: HalfHitch) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        
        return script.nullTerminated { script in
            guard let raw = script.raw() else { return nil }
            
            // Even though JS_Eval() takes an input count, it requires that the
            // input string be null terminated; it will ignore the input count
            // and extend beyond if not.
            
            let result = JS_Eval(context,
                                 raw,
                                 script.count,
                                 "filename",
                                 0)
            defer { JS_FreeValue(context, result) }

            guard let _ = recordIf(exception: result) else { return nil }
            
            return true
        }
    }
    @discardableResult
    @inlinable public func eval(_ script: Hitch) -> Bool? { return eval(script.halfhitch()) }
    @discardableResult
    @inlinable public func eval(_ script: String) -> Bool? { return eval(HalfHitch(string: script)) }
    @discardableResult
    @inlinable public func eval(_ script: StaticString) -> Bool? { return eval(HalfHitch(stringLiteral: script)) }
    @discardableResult
    @inlinable public func eval(_ script: Data) -> Bool? { return eval(HalfHitch(data: script)) }
    
    
    // MARK: - JS Resolution
    @inlinable
    public subscript<T: Decodable> (decoded exec: HalfHitch) -> T? {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let value = resolve(exec) else { return nil }
            defer { JS_FreeValue(context, value) }
            return JSValueToDecodable(context, value)
        }
    }
    @inlinable public subscript<T: Decodable> (decoded exec: Hitch) -> T? { get { return self[decoded: exec.halfhitch()] } }
    @inlinable public subscript<T: Decodable> (decoded exec: String) -> T? { get { return self[decoded: HalfHitch(string: exec)] } }
    @inlinable public subscript<T: Decodable> (decoded exec: StaticString) -> T? { get { return self[decoded: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript<T: Decodable> (decoded exec: Data) -> T? { get { return self[decoded: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (function exec: HalfHitch) -> JibFunction? {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let value = resolve(exec) else { return nil }
            defer { JS_FreeValue(context, value) }
            return JSValueToFunction(context, value)
        }
    }
    @inlinable public subscript (function exec: Hitch) -> JibFunction? { get { return self[function: exec.halfhitch()] } }
    @inlinable public subscript (function exec: String) -> JibFunction? { get { return self[function: HalfHitch(string: exec)] } }
    @inlinable public subscript (function exec: StaticString) -> JibFunction? { get { return self[function: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (function exec: Data) -> JibFunction? { get { return self[function: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (hitch exec: HalfHitch) -> Hitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let value = resolve(exec) else { return nil }
            defer { JS_FreeValue(context, value) }
            return JSValueToHitch(context, value)
        }
    }
    @inlinable public subscript (hitch exec: Hitch) -> Hitch? { get { return self[hitch: exec.halfhitch()] } }
    @inlinable public subscript (hitch exec: String) -> Hitch? { get { return self[hitch: HalfHitch(string: exec)] } }
    @inlinable public subscript (hitch exec: StaticString) -> Hitch? { get { return self[hitch: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (hitch exec: Data) -> Hitch? { get { return self[hitch: HalfHitch(data: exec)] } }
    
    
    @inlinable
    public subscript (halfhitch exec: HalfHitch) -> HalfHitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let value = resolve(exec) else { return nil }
            defer { JS_FreeValue(context, value) }
            return JSValueToHitch(context, value)?.halfhitch()
        }
    }
    @inlinable public subscript (halfhitch exec: Hitch) -> HalfHitch? { get { return self[halfhitch: exec.halfhitch()] } }
    @inlinable public subscript (halfhitch exec: String) -> HalfHitch? { get { return self[halfhitch: HalfHitch(string: exec)] } }
    @inlinable public subscript (halfhitch exec: StaticString) -> HalfHitch? { get { return self[halfhitch: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (halfhitch exec: Data) -> HalfHitch? { get { return self[halfhitch: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (string exec: HalfHitch) -> String? {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let value = resolve(exec) else { return nil }
            defer { JS_FreeValue(context, value) }
            return JSValueToHitch(context, value)?.toString()
        }
    }
    @inlinable public subscript (string exec: Hitch) -> String? { get { return self[string: exec.halfhitch()] } }
    @inlinable public subscript (string exec: String) -> String? { get { return self[string: HalfHitch(string: exec)] } }
    @inlinable public subscript (string exec: StaticString) -> String? { get { return self[string: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (string exec: Data) -> String? { get { return self[string: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (date exec: HalfHitch) -> Date? {
        get {
            guard let value = self[hitch: exec] else { return nil }
            return value.toString().date()
        }
    }
    @inlinable public subscript (date exec: Hitch) -> Date? { get { return self[date: exec.halfhitch()] } }
    @inlinable public subscript (date exec: String) -> Date? { get { return self[date: HalfHitch(string: exec)] } }
    @inlinable public subscript (date exec: StaticString) -> Date? { get { return self[date: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (date exec: Data) -> Date? { get { return self[date: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (double exec: HalfHitch) -> Double? {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let value = resolve(exec) else { return nil }
            defer { JS_FreeValue(context, value) }
            return JSValueToDouble(context, value)
        }
    }
    @inlinable public subscript (double exec: Hitch) -> Double? { get { return self[double: exec.halfhitch()] } }
    @inlinable public subscript (double exec: String) -> Double? { get { return self[double: HalfHitch(string: exec)] } }
    @inlinable public subscript (double exec: StaticString) -> Double? { get { return self[double: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (double exec: Data) -> Double? { get { return self[double: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (int exec: HalfHitch) -> Int? {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let value = resolve(exec) else { return nil }
            defer { JS_FreeValue(context, value) }
            return JSValueToInt(context, value)
        }
    }
    @inlinable public subscript (int exec: Hitch) -> Int? { get { return self[int: exec.halfhitch()] } }
    @inlinable public subscript (int exec: String) -> Int? { get { return self[int: HalfHitch(string: exec)] } }
    @inlinable public subscript (int exec: StaticString) -> Int? { get { return self[int: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (int exec: Data) -> Int? { get { return self[int: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (bool exec: HalfHitch) -> Bool? {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let value = resolve(exec) else { return nil }
            defer { JS_FreeValue(context, value) }
            return JSValueToBool(context, value)
        }
    }
    @inlinable public subscript (bool exec: Hitch) -> Bool? { get { return self[bool: exec.halfhitch()] } }
    @inlinable public subscript (bool exec: String) -> Bool? { get { return self[bool: HalfHitch(string: exec)] } }
    @inlinable public subscript (bool exec: StaticString) -> Bool? { get { return self[bool: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (bool exec: Data) -> Bool? { get { return self[bool: HalfHitch(data: exec)] } }
    
    @inlinable
    public subscript (json exec: HalfHitch) -> Hitch? {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let value = resolve(exec) else { return nil }
            defer { JS_FreeValue(context, value) }
            return JSValueToJson(context, value)
        }
    }
    @inlinable public subscript (json exec: Hitch) -> Hitch? { get { return self[json: exec.halfhitch()] } }
    @inlinable public subscript (json exec: String) -> Hitch? { get { return self[json: HalfHitch(string: exec)] } }
    @inlinable public subscript (json exec: StaticString) -> Hitch? { get { return self[json: HalfHitch(stringLiteral: exec)] } }
    @inlinable public subscript (json exec: Data) -> Hitch? { get { return self[json: HalfHitch(data: exec)] } }
    
    
    // MARK: - JS Creation
    
    @discardableResult
    public func set(global name: HalfHitch, value: JSValue) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        
        let atom = JS_NewAtom(context, name.raw())
        defer { JS_FreeAtom(context, atom) }
        
        if JS_SetProperty(context,
                          global,
                          atom,
                          value) != 1 {
            return recordException()
        }
        return true
    }
    
    @discardableResult
    public func set(global name: HalfHitch, value: JibFunction) -> Bool? {
        return set(global: name, value: value.functionValueRef)
    }
    
    @discardableResult
    public func new(function name: HalfHitch, body: @escaping JibFunctionBody) -> JibFunction? {
        lock.lock(); defer { lock.unlock() }
        guard let function = JibFunction(jib: self, name: name, body: body) else { return nil }
        customFunctions.append(function)
        return function
    }
    
    @discardableResult
    @inlinable
    func resolve(_ hitch: HalfHitch) -> JSValue? {
        // We're given a string, like:
        // "x"
        // "global.x"
        // "{  a  :  1}"
        // "{}"
        // and we need to resolve it to a JSValue
        
        
        // NOTE: like JSC, QuickJs fails to read an object ( {} ) without
        // said object being wrapped in parenthesis
        let modifiedHitch = "({0})" << [hitch]
        if let modifiedValue: JSValue? = modifiedHitch.nullTerminated({ script in
            guard let raw = script.raw() else { return nil }
            return JS_Eval(context,
                           raw,
                           script.count,
                           "filename",
                           0)
        }) {
            if let modifiedValue = modifiedValue,
               JS_IsException(modifiedValue) == 0 {
                return modifiedValue
            }
        }

        return hitch.nullTerminated { script in
            guard let raw = script.raw() else { return nil }
            return JS_Eval(context,
                           raw,
                           script.count,
                           "filename",
                           0)
        }
    }
}
