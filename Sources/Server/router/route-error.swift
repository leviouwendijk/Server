import Foundation

public enum RouteError: Error, LocalizedError {
    case invalidMiddleware
    
    public var errorDescription: String? {
        switch self {
        case .invalidMiddleware:
            return "Failed to initialize middleware object inside route (use)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidMiddleware:
            return "The middleware object was not present"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidMiddleware:
            return "Ensure the middleware initializer doesn't return nil"
        }
    }
}
