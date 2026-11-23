import Foundation

public enum MiddlewareError: Error, LocalizedError {
    case emptyKey(String)

    public var errorDescription: String? {
        switch self {
        case .emptyKey(let symbol):
            return "Environment variable \(symbol) is empty"
        }
    }

    public var failureReason: String? {
        switch self {
        case .emptyKey:
            return "The bearer key must not be empty"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .emptyKey(let symbol):
            return "Set \(symbol) in the service environment"
        }
    }
}
