import Foundation
import Structures

public func flattenJSONValue(_ value: JSONValue) -> [String: String] {
    var result: [String: String] = [:]
    flattenJSONValue(value, prefix: nil, into: &result)
    return result
}

private func flattenJSONValue(
    _ value: JSONValue,
    prefix: String?,
    into result: inout [String: String]
) {
    switch value {
    case .object(let dict):
        for (key, child) in dict.sorted(by: { $0.key < $1.key }) {
            let newPrefix = prefix.map { "\($0).\(key)" } ?? key
            flattenJSONValue(child, prefix: newPrefix, into: &result)
        }

    case .array(let array):
        for (index, child) in array.enumerated() {
            let part = "[\(index)]"
            let newPrefix: String
            if let prefix {
                newPrefix = prefix + part
            } else {
                newPrefix = part
            }
            flattenJSONValue(child, prefix: newPrefix, into: &result)
        }

    case .string(let s):
        result[prefix ?? "<root>"] = s

    case .int(let i):
        result[prefix ?? "<root>"] = String(i)

    case .double(let d):
        result[prefix ?? "<root>"] = String(d)

    case .bool(let b):
        result[prefix ?? "<root>"] = b ? "true" : "false"

    case .null:
        result[prefix ?? "<root>"] = "null"
    }
}
