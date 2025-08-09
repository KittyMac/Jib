#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

public class JibFunction: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeUndefined(context)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

