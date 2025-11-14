import Foundation

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
