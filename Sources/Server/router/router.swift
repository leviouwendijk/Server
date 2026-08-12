import Foundation
import HTTP

public struct Router: Sendable {
    public let routes: [Route]
    public let methods: Set<HTTPMethod>
    public let json: ServerJSONPolicy

    public init(
        methods: Set<HTTPMethod> = HTTPMethod.defaultServerAllowed,
        json: ServerJSONPolicy = .default,
        @RouteBuilder _ builder: () -> [Route]
    ) {
        self.routes = builder()
        self.methods = methods
        self.json = json
    }

    public init(
        routes: [Route],
        methods: Set<HTTPMethod> = HTTPMethod.defaultServerAllowed,
        json: ServerJSONPolicy = .default
    ) {
        self.routes = routes
        self.methods = methods
        self.json = json
    }
// public struct Router: Sendable {
//     public let routes: [Route]
//     public let methods: Set<HTTPMethod>

//     public init(
//         methods: Set<HTTPMethod> = HTTPMethod.defaultServerAllowed,
//         @RouteBuilder _ builder: () -> [Route]
//     ) {
//         self.routes = builder()
//         self.methods = methods
//     }

//     public init(
//         routes: [Route],
//         methods: Set<HTTPMethod> = HTTPMethod.defaultServerAllowed
//     ) {
//         self.routes = routes
//         self.methods = methods
//     }

    public func route(
        _ request: HTTPRequest
    ) async -> HTTPResponse {
        await observed(
            request
        ).response
    }

    func exactRoute(
        for request: HTTPRequest
    ) -> Route? {
        routes.first {
            $0.method == request.method
                && $0.path == request.path
        }
    }

    func syntheticOptionsRoute(
        for request: HTTPRequest
    ) -> Route? {
        routes.first {
            $0.path == request.path
                && $0.syntheticMethods.contains(.options)
        }
    }

    func syntheticHeadRoute(
        for request: HTTPRequest
    ) -> Route? {
        routes.first {
            $0.method == .get
                && $0.path == request.path
                && $0.syntheticMethods.contains(.head)
        }
    }

    func fallback(
        for request: HTTPRequest
    ) -> HTTPResponse {
        let hasPath = routes.contains {
            $0.path == request.path
        }

        if hasPath {
            return .methodNotAllowed(
                body: "Method \(request.method.rawValue) not allowed for \(request.path)"
            )
        }

        return .notFound(
            body: "No route for \(request.method.rawValue) \(request.path)"
        )
    }

    func run(
        _ route: Route,
        _ request: HTTPRequest
    ) async -> HTTPResponse {
        var handler = route.handler

        for middleware in route.middleware.reversed() {
            let next = handler
            let middleware = middleware

            handler = { request, router in
                await middleware.handle(
                    request,
                    router,
                    next: next
                )
            }
        }

        let policy = route.jsonPolicy ?? json

        return await HTTPJSONCoding.$current.withValue(
            policy.coding
        ) {
            await handler(
                request,
                self
            )
        }
    }

    // func run(
    //     _ route: Route,
    //     _ request: HTTPRequest
    // ) async -> HTTPResponse {
    //     var handler = route.handler

    //     for middleware in route.middleware.reversed() {
    //         let next = handler
    //         let middleware = middleware

    //         handler = { request, router in
    //             await middleware.handle(
    //                 request,
    //                 router,
    //                 next: next
    //             )
    //         }
    //     }

    //     return await handler(
    //         request,
    //         self
    //     )
    // }

    public func listRoutes() -> RouteList {
        RouteList(
            routes: routes.map {
                RouteSummary(
                    from: $0
                )
            }
        )
    }

    public func listRoutesAsStrings() -> [String] {
        routes.map {
            "\($0.method.rawValue) \($0.path)"
        }
    }
}

// public struct Router: Sendable {
//     public let routes: [Route]
//     public let methods: Set<HTTPMethod>

//     public init(
//         methods: Set<HTTPMethod> = HTTPMethod.defaultServerAllowed,
//         @RouteBuilder _ builder: () -> [Route]
//     ) {
//         self.routes = builder()
//         self.methods = methods
//     }

//     public init(
//         routes: [Route],
//         methods: Set<HTTPMethod> = HTTPMethod.defaultServerAllowed
//     ) {
//         self.routes = routes
//         self.methods = methods
//     }

//     public func route(
//         _ request: HTTPRequest
//     ) async -> HTTPResponse {
//         guard methods.contains(request.method) else {
//             return .methodNotAllowed(
//                 body: "Method \(request.method.rawValue) is disabled by server policy"
//             )
//         }

//         if let route = exactRoute(for: request) {
//             return await run(
//                 route,
//                 request
//             )
//         }

//         if request.method == .options,
//            let route = syntheticOptionsRoute(for: request) {
//             return await run(
//                 route,
//                 request
//             )
//         }

//         if request.method == .head,
//            let route = syntheticHeadRoute(for: request) {
//             var response = await run(
//                 route,
//                 request
//             )

//             response.body = ""

//             return response
//         }

//         return fallback(
//             for: request
//         )
//     }

//     private func exactRoute(
//         for request: HTTPRequest
//     ) -> Route? {
//         routes.first {
//             $0.method == request.method
//                 && $0.path == request.path
//         }
//     }

//     private func syntheticOptionsRoute(
//         for request: HTTPRequest
//     ) -> Route? {
//         routes.first {
//             $0.path == request.path
//                 && $0.syntheticMethods.contains(.options)
//         }
//     }

//     private func syntheticHeadRoute(
//         for request: HTTPRequest
//     ) -> Route? {
//         routes.first {
//             $0.method == .get
//                 && $0.path == request.path
//                 && $0.syntheticMethods.contains(.head)
//         }
//     }

//     private func fallback(
//         for request: HTTPRequest
//     ) -> HTTPResponse {
//         let hasPath = routes.contains {
//             $0.path == request.path
//         }

//         if hasPath {
//             return .methodNotAllowed(
//                 body: "Method \(request.method.rawValue) not allowed for \(request.path)"
//             )
//         }

//         return .notFound(
//             body: "No route for \(request.method.rawValue) \(request.path)"
//         )
//     }

//     private func run(
//         _ route: Route,
//         _ request: HTTPRequest
//     ) async -> HTTPResponse {
//         var handler = route.handler

//         for middleware in route.middleware.reversed() {
//             let next = handler
//             let middleware = middleware

//             handler = { request, router in
//                 await middleware.handle(
//                     request,
//                     router,
//                     next: next
//                 )
//             }
//         }

//         return await handler(
//             request,
//             self
//         )
//     }

//     public func listRoutes() -> RouteList {
//         RouteList(
//             routes: routes.map {
//                 RouteSummary(from: $0)
//             }
//         )
//     }

//     public func listRoutesAsStrings() -> [String] {
//         routes.map {
//             "\($0.method.rawValue) \($0.path)"
//         }
//     }
// }
