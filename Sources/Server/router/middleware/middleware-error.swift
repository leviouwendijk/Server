import Foundation

public enum MiddlewareError: Error, LocalizedError {
    case failedToInitializeEmptySymbol
    
    public var errorDescription: String? {
        switch self {
        case .failedToInitializeEmptySymbol:
            return "Failed to initialize middleware object"
        }
    }

    public var failureReason: String? {
        switch self {
        case .failedToInitializeEmptySymbol:
            return "The symbol provided to the initializer is empty"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .failedToInitializeEmptySymbol:
            return "Ensure that passing optionals to the initializer resolves to a non-nil value"
        }
    }
}
