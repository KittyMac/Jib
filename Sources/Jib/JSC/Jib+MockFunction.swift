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
    
    @inlinable
    public override func createJibValue(_ context: JSGlobalContextRef) -> JibValue {
        return JSValueMakeUndefined(context)
    }
    
    @inlinable
    public override func createJibValue(_ jib: Jib) -> JibValue {
        return createJibValue(jib.context)
    }
}


