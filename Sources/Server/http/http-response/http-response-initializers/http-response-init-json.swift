import Foundation
import Structures
import plate

public extension HTTPResponse {
    /// Create a JSON response from JSONValue
    static func json(
        _ object: [String: JSONValue],
        status: HTTPStatus = .ok,
        headers: [String: String] = [:]
    ) throws -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(object)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ServerError.responseEncodingFailed
        }
        
        var h = headers
        h["Content-Type"] = "application/json; charset=utf-8"
        return HTTPResponse(status: status, headers: h, body: json)
    }
    
    /// Create a JSON response from a single JSONValue
    static func json(
        _ value: JSONValue,
        status: HTTPStatus = .ok,
        headers: [String: String] = [:]
    ) throws -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ServerError.responseEncodingFailed
        }
        
        var h = headers
        h["Content-Type"] = "application/json; charset=utf-8"
        return HTTPResponse(status: status, headers: h, body: json)
    }
    
    /// Create a JSON response from an array of JSONValue
    static func json(
        _ array: [JSONValue],
        status: HTTPStatus = .ok,
        headers: [String: String] = [:]
    ) throws -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(array)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ServerError.responseEncodingFailed
        }
        
        var h = headers
        h["Content-Type"] = "application/json; charset=utf-8"
        return HTTPResponse(status: status, headers: h, body: json)
    }
}
