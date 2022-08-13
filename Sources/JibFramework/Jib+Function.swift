#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

import Foundation
import Hitch

public typealias JibFunctionBody = ([Hitch]) -> JibUnknown?



