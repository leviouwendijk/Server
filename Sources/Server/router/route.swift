import Foundation

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
}

// public struct Route: Sendable {
//     public let method: HTTPMethod
//     public let path: String
//     public let handler: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    
//     public init(
//         method: HTTPMethod,
//         path: String,
//         handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
//     ) {
//         self.method = method
//         self.path = path
//         self.handler = handler
//     }
// }
