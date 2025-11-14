import Foundation

public struct Route: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let handler: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    
    public init(
        method: HTTPMethod,
        path: String,
        handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
    ) {
        self.method = method
        self.path = path
        self.handler = handler
    }
}

public struct Router: Sendable {
    public let routes: [Route]
    
    public init(@RouteBuilder _ builder: () -> [Route]) {
        self.routes = builder()
    }
    
    public init(routes: [Route]) {
        self.routes = routes
    }
    
    public func route(_ request: HTTPRequest) async -> HTTPResponse {
        // Exact match first
        if let route = routes.first(where: { $0.method == request.method && $0.path == request.path }) {
            return await route.handler(request, self)
        }
        
        // Check if path exists with different method
        let hasPath = routes.contains { $0.path == request.path }
        if hasPath {
            return .methodNotAllowed(body: "Method \(request.method.rawValue) not allowed for \(request.path)")
        }
        
        // Path not found
        return .notFound(body: "No route for \(request.method.rawValue) \(request.path)")
    }
    
    /// Get all available routes
    public func listRoutes() -> [String] {
        routes.map { "\($0.method.rawValue) \($0.path)" }
    }
}
