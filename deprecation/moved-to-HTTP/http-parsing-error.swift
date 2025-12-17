import Foundation

public enum HTTPParsingError: Error, LocalizedError {
    case invalidRequestLine(String)
    case invalidMethod(String)
    case invalidStatusLine(String)
    case invalidStatusCode(String)
    case malformedHeaders
    case incompleteRequest
    case incompleteResponse
    
    public var errorDescription: String? {
        switch self {
        case .invalidRequestLine(let line):
            return "Invalid request line: \(line)"
        case .invalidMethod(let method):
            return "Invalid HTTP method: \(method)"
        case .invalidStatusLine(let line):
            return "Invalid status line: \(line)"
        case .invalidStatusCode(let code):
            return "Invalid status code: \(code)"
        case .malformedHeaders:
            return "Headers are malformed"
        case .incompleteRequest:
            return "Request is incomplete"
        case .incompleteResponse:
            return "Response is incomplete"
        }
    }
}
