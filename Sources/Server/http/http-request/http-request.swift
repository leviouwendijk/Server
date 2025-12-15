import Foundation
// import Structures
import Primitives

public struct HTTPRequest: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let headers: [String: String]
    public let body: String
    
    public init(
        method: HTTPMethod,
        path: String,
        headers: [String: String],
        body: String = ""
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
    
    /// Extracts the Bearer token (case-insensitive)
    public func bearerToken() -> String? {
        guard let header = headers.first(where: { $0.key.lowercased() == "authorization" })?.value else {
            return nil
        }
        
        let prefix = "bearer "
        let lower = header.lowercased()
        guard lower.hasPrefix(prefix), header.count > prefix.count else {
            return nil
        }
        
        let tokenStart = header.index(header.startIndex, offsetBy: prefix.count)
        let token = header[tokenStart...].trimmingCharacters(in: .whitespaces)
        return token.isEmpty ? nil : token
    }
    
    /// Extract any custom authorization value
    public func authorizationHeader() -> String? {
        headers.first(where: { $0.key.lowercased() == "authorization" })?.value
    }
    
    /// Get header value (case-insensitive)
    public func header(_ name: String) -> String? {
        headers.first(where: { $0.key.lowercased() == name.lowercased() })?.value
    }

}

extension HTTPRequest {
    /// Decode request body into a Decodable type
    public func decode<T: Decodable>(
        _ type: T.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        guard let data = body.data(using: .utf8) else {
            throw HTTPParsingError.malformedHeaders
        }
        return try decoder.decode(T.self, from: data)
    }

    /// Sugar for decode<T: Decodable> method
    public func extract<T: Decodable>(
        _ type: T.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        return try self.decode(T.self, using: decoder)
    }
    
    /// Decode body as JSON object and get a single key
    public func key<T: Decodable>(
        _ key: String,
        as type: T.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        guard let data = body.data(using: .utf8) else {
            throw HTTPParsingError.malformedHeaders
        }
        
        let json = try decoder.decode([String: JSONValue].self, from: data)
        guard let value = json[key] else {
            throw HTTPParsingError.malformedHeaders
        }
        
        // Re-encode the value and decode to T
        let valueData = try JSONEncoder().encode(value)
        return try decoder.decode(T.self, from: valueData)
    }
    
    /// Decode body as JSON object and extract multiple keys
    public func keys(
        _ keys: [String],
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> [String: JSONValue] {
        guard let data = body.data(using: .utf8) else {
            throw HTTPParsingError.malformedHeaders
        }
        
        let json = try decoder.decode([String: JSONValue].self, from: data)
        var result: [String: JSONValue] = [:]
        
        for key in keys {
            if let value = json[key] {
                result[key] = value
            }
        }
        
        return result
    }
}
