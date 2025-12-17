import Foundation

public enum HTTPStatusFamily: CaseIterable, Hashable, Sendable {
    case informational   // 1xx
    case success         // 2xx
    case redirection     // 3xx
    case clientError     // 4xx
    case serverError     // 5xx
    case other           // everything else / weird

    public init(code: Int) {
        switch code {
        case 100..<200: self = .informational
        case 200..<300: self = .success
        case 300..<400: self = .redirection
        case 400..<500: self = .clientError
        case 500..<600: self = .serverError
        default:        self = .other
        }
    }

    public init(from status: HTTPStatus) {
        self.init(code: status.code)
    }

    public var suffix: String {
        switch self {
        case .informational: return "1xx"
        case .success:       return "2xx"
        case .redirection:   return "3xx"
        case .clientError:   return "4xx"
        case .serverError:   return "5xx"
        case .other:         return "other"
        }
    }
}
