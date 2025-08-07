#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

public class JibMockFunction: JibFunction {
    let evalName: String
    
    @usableFromInline
    init?(jib: Jib, evalName: String) {
        self.evalName = evalName
    }
}

extension JibMockFunction: JibUnknown {
    @inlinable
    public func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeUndefined(context)
    }
    
    @inlinable
    public func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}

