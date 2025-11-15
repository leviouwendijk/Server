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

public struct Route: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let handler: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    public var middleware: [Middleware] = []
    
    public init(
        method: HTTPMethod,
        path: String,
        handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
    ) {
        self.method = method
        self.path = path
        self.handler = handler
    }
    
    public func use(_ m: Middleware) -> Route {
        var copy = self
        copy.middleware.append(m)
        return copy
    }
    
    public func use(_ middleware: [Middleware]) -> Route {
        var copy = self
        copy.middleware.append(contentsOf: middleware)
        return copy
    }

    public func use(_ m: Middleware?) throws -> Route {
        guard let m else { throw RouteError.invalidMiddleware } 
        return self.use(m)
    }
    
    public func use(_ middleware: [Middleware]?) throws -> Route {
        guard let middleware else { throw RouteError.invalidMiddleware } 
        return self.use(middleware)
    }
}
