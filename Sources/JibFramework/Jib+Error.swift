#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

struct RuntimeError: Error, CustomStringConvertible {
    let message: Hitch

    init(_ message: Hitch) {
        self.message = message
    }

    public var localizedDescription: String {
        return message.description
    }
    
    public var description: String {
        return message.description
    }
}
