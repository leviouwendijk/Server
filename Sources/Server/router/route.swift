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

    /// Extra methods that are allowed to "ride" this route
    /// (e.g. OPTIONS riding POST, HEAD riding GET).
    public var syntheticMethods: Set<HTTPMethod> = []
    
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

    public func use(_ middleware: Middleware...) -> Route {
        return self.use(middleware)
    }

    public func use(_ m: Middleware?) throws -> Route {
        guard let m else { throw RouteError.invalidMiddleware } 
        return self.use(m)
    }
    
    public func use(_ middleware: [Middleware]?) throws -> Route {
        guard let middleware else { throw RouteError.invalidMiddleware } 
        return self.use(middleware)
    }

    public func allow(_ methods: [HTTPMethod]) -> Route {
        var copy = self
        copy.syntheticMethods.formUnion(methods)
        return copy
    }

    public func allow(_ methods: HTTPMethod...) -> Route {
        allow(methods)
    }
}

extension Array where Element == Route {
    // WARNNING: activation creates ambiguity between
    // [Route] .use extension and group().use extension.
    // The compiler will not be able to distinguish these then.
    // Fix #1: add variadic overload to allow conv.?
    // Fix #2: use 1 return type from group() to build routes from, not two
    //
    public func use(_ m: Middleware) -> [Route] {
        map { $0.use(m) }
    }

    public func use(_ middleware: [Middleware]) -> [Route] {
        map { $0.use(middleware) }
    }

    public func use(_ middleware: Middleware...) -> [Route] {
        return use(middleware)
    }

    public func use(_ m: Middleware?) throws -> [Route] {
        guard let m else { throw RouteError.invalidMiddleware }
        return use(m)
    }

    public func use(_ middleware: [Middleware]?) throws -> [Route] {
        guard let middleware else { throw RouteError.invalidMiddleware }
        return use(middleware)
    }

    public func allow(_ methods: [HTTPMethod]) -> [Route] {
        map { $0.allow(methods) }
    }

    public func allow(_ methods: HTTPMethod...) -> [Route] {
        allow(methods)
    }
}
