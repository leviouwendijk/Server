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
        // Exact method + path
        if let route = exactRoute(for: request) {
            return await run(route: route, for: request)
        }
        
        // Synthetic OPTIONS riding another route (if allowed)
        if request.method == .options, let route = syntheticOptionsRoute(for: request) {
            return await run(route: route, for: request)
        }
        
        // Synthetic HEAD riding GET (if allowed)
        if request.method == .head, let route = syntheticHeadRoute(for: request) {
            var resp = await run(route: route, for: request)
            resp.body = ""
            return resp
        }
        
        // Fallback: 405 vs 404
        return defaultResponse(for: request)
    }
    
    /// Exact method + path match.
    private func exactRoute(for request: HTTPRequest) -> Route? {
        routes.first { $0.method == request.method && $0.path == request.path }
    }
    
    /// OPTIONS may ride any route on the same path that explicitly allows it.
    private func syntheticOptionsRoute(for request: HTTPRequest) -> Route? {
        routes.first {
            $0.path == request.path &&
            $0.syntheticMethods.contains(.options)
        }
    }
    
    /// HEAD may ride a GET route on the same path that explicitly allows it.
    private func syntheticHeadRoute(for request: HTTPRequest) -> Route? {
        routes.first {
            $0.method == .get &&
            $0.path == request.path &&
            $0.syntheticMethods.contains(.head)
        }
    }
    
    /// Shared 405 / 404 logic.
    private func defaultResponse(for request: HTTPRequest) -> HTTPResponse {
        let hasPath = routes.contains { $0.path == request.path }
        if hasPath {
            return .methodNotAllowed(
                body: "Method \(request.method.rawValue) not allowed for \(request.path)"
            )
        } else {
            return .notFound(
                body: "No route for \(request.method.rawValue) \(request.path)"
            )
        }
    }
    
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
