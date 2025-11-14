import Foundation

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
            // Apply middleware chain
            var handler: @Sendable (HTTPRequest, Router) async -> HTTPResponse = route.handler
            for middleware in route.middleware.reversed() {
                let next = handler
                let mw = middleware
                handler = { req, router in
                    await mw.handle(req, router, next: next)
                }
            }
            return await handler(request, self)
        }
        
        // Check if path exists with different method
        let hasPath = routes.contains { $0.path == request.path }
        if hasPath {
            return .methodNotAllowed(body: "Method \(request.method.rawValue) not allowed for \(request.path)")
        }
        
        // Path not found
        return .notFound(body: "No route for \(request.method.rawValue) \(request.path)")
    }
    
    /// Get all available routes as RouteList
    public func listRoutes() -> RouteList {
        let summaries = routes.map { RouteSummary(from: $0) }
        return RouteList(routes: summaries)
    }
    
    /// Get routes as array of strings (legacy)
    public func listRoutesAsStrings() -> [String] {
        routes.map { "\($0.method.rawValue) \($0.path)" }
    }
}
