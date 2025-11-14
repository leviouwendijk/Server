import Foundation

public enum HTTPMethod: String, Sendable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
    case trace = "TRACE"
    case connect = "CONNECT"
    
    public init?(caseInsensitive rawValue: String) {
        self.init(rawValue: rawValue.uppercased())
    }
}
