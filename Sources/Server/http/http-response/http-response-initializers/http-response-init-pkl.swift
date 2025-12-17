import Foundation
// import Structures
import Primitives
// import plate

internal func renderJSONValueAsPKL(_ value: JSONValue, indent: Int = 0, indent_size: Int = 4) -> String {
    let indentStr = String(repeating: " ", count: indent * indent_size)
    
    switch value {
    case .null:
        return "null"
    case .bool(let b):
        return b ? "true" : "false"
    case .int(let i):
        return String(i)
    case .double(let d):
        return String(d)
    case .string(let s):
        return "\"\(s.replacingOccurrences(of: "\"", with: "\\\""))\""
    case .array(let arr):
        if arr.isEmpty {
            return "[]"
        }
        let childIndent = indent + 1
        let childIndentStr = String(repeating: " ", count: childIndent * indent_size)
        let items = arr.map { childIndentStr + renderJSONValueAsPKL($0, indent: childIndent) }
            .joined(separator: "\n")
        return "[\n\(items)\n\(indentStr)]"
    case .object(let obj):
        if obj.isEmpty {
            return "{}"
        }
        let childIndent = indent + 1
        let childIndentStr = String(repeating: " ", count: childIndent * indent_size)
        let items = obj.sorted { $0.key < $1.key }
            .map { key, val in
                let renderedVal = renderJSONValueAsPKL(val, indent: childIndent)
                return "\(childIndentStr)\(key) = \(renderedVal)"
            }
            .joined(separator: "\n")
        return "{\n\(items)\n\(indentStr)}"
    }
}

public extension HTTPResponse {
    /// Create a PKL response from a string
    static func pkl(
        _ content: String,
        status: HTTPStatus = .ok,
        headers: [String: String] = [:]
    ) -> HTTPResponse {
        var h = headers
        h["Content-Type"] = "text/pkl; charset=utf-8"
        return HTTPResponse(status: status, headers: h, body: content)
    }
    
    /// Create a PKL response from a JSONValue (render as PKL structure)
    static func pkl(
        _ value: JSONValue,
        status: HTTPStatus = .ok,
        headers: [String: String] = [:]
    ) throws -> HTTPResponse {
        let pklString = renderJSONValueAsPKL(value)
        var h = headers
        h["Content-Type"] = "text/pkl; charset=utf-8"
        return HTTPResponse(status: status, headers: h, body: pklString)
    }
    
    /// Create a PKL response from a dictionary structure
    static func pkl(
        _ object: [String: JSONValue],
        status: HTTPStatus = .ok,
        headers: [String: String] = [:]
    ) throws -> HTTPResponse {
        let pklString = renderJSONValueAsPKL(.object(object))
        var h = headers
        h["Content-Type"] = "text/pkl; charset=utf-8"
        return HTTPResponse(status: status, headers: h, body: pklString)
    }
    
    /// Create a PKL response from an array of JSONValue
    static func pkl(
        _ array: [JSONValue],
        status: HTTPStatus = .ok,
        headers: [String: String] = [:]
    ) throws -> HTTPResponse {
        let pklString = renderJSONValueAsPKL(.array(array))
        var h = headers
        h["Content-Type"] = "text/pkl; charset=utf-8"
        return HTTPResponse(status: status, headers: h, body: pklString)
    }
}
