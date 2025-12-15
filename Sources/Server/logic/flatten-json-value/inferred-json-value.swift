import Foundation
// import Structures
import Primitives

internal func inferredJSONTypeName(_ value: JSONValue) -> String {
    switch value {
    case .object: return "Object"
    case .array:  return "Array"
    case .string: return "String"
    case .int:    return "Int"
    case .double: return "Double"
    case .bool:   return "Bool"
    case .null:   return "Null"
    }
}
