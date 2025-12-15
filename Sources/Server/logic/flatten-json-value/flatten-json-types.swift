import Foundation
// import Structures
import Primitives

public func flattenJSONTypes(_ value: JSONValue) -> [String: String] {
    var result: [String: String] = [:]
    flattenJSONTypes(value, prefix: nil, into: &result)
    return result
}

private func flattenJSONTypes(
    _ value: JSONValue,
    prefix: String?,
    into result: inout [String: String]
) {
    switch value {
    case .object(let dict):
        if let prefix {
            result[prefix] = "Object"
        } else {
            result["<root>"] = "Object"
        }
        for (key, child) in dict.sorted(by: { $0.key < $1.key }) {
            let newPrefix = prefix.map { "\($0).\(key)" } ?? key
            flattenJSONTypes(child, prefix: newPrefix, into: &result)
        }

    case .array(let array):
        let key = prefix ?? "<root>"
        let elementType = array.first.map { inferredJSONTypeName($0) } ?? "Unknown"
        result[key] = "Array<\(elementType)>"

        for (index, child) in array.enumerated() {
            let part = "[\(index)]"
            let newPrefix: String
            if let prefix {
                newPrefix = prefix + part
            } else {
                newPrefix = part
            }
            flattenJSONTypes(child, prefix: newPrefix, into: &result)
        }

    case .string, .int, .double, .bool, .null:
        let key = prefix ?? "<root>"
        result[key] = inferredJSONTypeName(value)
    }
}
