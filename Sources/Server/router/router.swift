import Foundation

public struct Router: Sendable {
    public let routes: [Route]
    
    public init(
        @RouteBuilder _ builder: () -> [Route],
        // appendOptions: Bool = false
    ) {
        self.routes = builder()
        // let routes = builder()
        // if appendOptions {
        //     self.routes = routes.appendingOptions()
        // } else {
        //     self.routes = routes
        // }
    }
    
    public init(
        routes: [Route],
        // appendOptions: Bool = false
    ) {
        self.routes = routes
        // if appendOptions {
        //     self.routes = routes.appendingOptions()
        // } else {
        //     self.routes = routes
        // }
    }
    
    // public func route(_ request: HTTPRequest) async -> HTTPResponse {
    //     // Exact match first
    //     if let route = routes.first(where: { $0.method == request.method && $0.path == request.path }) {
    //         // Apply middleware chain
    //         var handler: @Sendable (HTTPRequest, Router) async -> HTTPResponse = route.handler
    //         for middleware in route.middleware.reversed() {
    //             let next = handler
    //             let mw = middleware
    //             handler = { req, router in
    //                 await mw.handle(req, router, next: next)
    //             }
    //         }
    //         return await handler(request, self)
    //     }
        
    //     // Check if path exists with different method
    //     let hasPath = routes.contains { $0.path == request.path }
    //     if hasPath {
    //         return .methodNotAllowed(body: "Method \(request.method.rawValue) not allowed for \(request.path)")
    //     }
        
    //     // Path not found
    //     return .notFound(body: "No route for \(request.method.rawValue) \(request.path)")
    // }

    public func route(_ request: HTTPRequest) async -> HTTPResponse {
        // Try exact method + path
        if let route = routes.first(where: { $0.method == request.method && $0.path == request.path }) {
            return await run(route: route, for: request)
        }

        // Special case: OPTIONS should "ride" any existing path and let middleware handle it
        if request.method == .options {
            if let route = routes.first(where: { $0.path == request.path }) {
                // Reuse that route's middleware chain (CORS, auth, rate-limit, etc.)
                return await run(route: route, for: request)
            }

            // No route for this path at all -> 404 is fine for OPTIONS too
            return .notFound(body: "No route for \(request.method.rawValue) \(request.path)")
        }

        // Non-OPTIONS: preserve existing 405/404 behavior
        let hasPath = routes.contains { $0.path == request.path }
        if hasPath {
            return .methodNotAllowed(body: "Method \(request.method.rawValue) not allowed for \(request.path)")
        }

        return .notFound(body: "No route for \(request.method.rawValue) \(request.path)")
    }

    // factor out the middleware chain so we don't duplicate it
    private func run(route: Route, for request: HTTPRequest) async -> HTTPResponse {
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
