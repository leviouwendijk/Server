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

    func allowedMethods(
        for path: HTTPPath
    ) -> [HTTPMethod] {
        let routesAtPath = routes.filter {
            $0.path == path
        }

        guard !routesAtPath.isEmpty else {
            return []
        }

        var allowed = Set<HTTPMethod>()

        for route in routesAtPath {
            if methods.contains(
                route.method
            ) {
                allowed.insert(
                    route.method
                )
            }

            for syntheticMethod in route.syntheticMethods
            where methods.contains(
                syntheticMethod
            ) {
                allowed.insert(
                    syntheticMethod
                )
            }
        }

        if methods.contains(
            .options
        ) {
            allowed.insert(
                .options
            )
        }

        return allowed.sorted {
            $0.rawValue < $1.rawValue
        }
    }

    func acceptedQuery(
        for path: HTTPPath
    ) -> HTTPAcceptQuery? {
        guard methods.contains(
            .query
        ) else {
            return nil
        }

        return routes.first {
            $0.path == path
                && $0.method == .query
                && $0.acceptedQuery != nil
        }?.acceptedQuery
    }

    func applyingQueryAdvertisement(
        to response: HTTPResponse,
        for path: HTTPPath
    ) -> HTTPResponse {
        guard let acceptedQuery = acceptedQuery(
            for: path
        ) else {
            return response
        }

        var response = response
        response.headers.acceptQuery = acceptedQuery
        return response
    }

    func parsedMediaType(
        _ rawValue: String
    ) -> (
        value: String,
        parameters: [String: String]
    )? {
        let segments = rawValue.split(
            separator: ";",
            omittingEmptySubsequences: false
        )

        guard let rawMediaType = segments.first else {
            return nil
        }

        let mediaType = rawMediaType
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        let parts = mediaType.split(
            separator: "/",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )

        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty
        else {
            return nil
        }

        var parameters: [String: String] = [:]

        for rawParameter in segments.dropFirst() {
            let pair = rawParameter.split(
                separator: "=",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )

            guard pair.count == 2 else {
                return nil
            }

            let name = pair[0]
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

            guard !name.isEmpty else {
                return nil
            }

            var value = pair[1]
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            if value.count >= 2,
               value.hasPrefix("\""),
               value.hasSuffix("\"") {
                value.removeFirst()
                value.removeLast()
            }

            parameters[name] = value
        }

        return (
            value: mediaType,
            parameters: parameters
        )
    }

    func queryContentType(
        _ contentType: String,
        isAcceptedBy acceptedQuery: HTTPAcceptQuery
    ) -> Bool {
        guard let requested = parsedMediaType(
            contentType
        ) else {
            return false
        }

        let requestedParts = requested.value.split(
            separator: "/",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )

        guard requestedParts.count == 2 else {
            return false
        }

        let requestedType = String(
            requestedParts[0]
        )

        let requestedSubtype = String(
            requestedParts[1]
        )

        return acceptedQuery.mediaRanges.contains { mediaRange in
            let candidate = mediaRange.value.lowercased()

            let candidateParts = candidate.split(
                separator: "/",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )

            guard candidateParts.count == 2 else {
                return false
            }

            let candidateType = String(
                candidateParts[0]
            )

            let candidateSubtype = String(
                candidateParts[1]
            )

            let mediaMatches =
                candidateType == "*"
                    && candidateSubtype == "*"
                || candidateType == requestedType
                    && candidateSubtype == "*"
                || candidateType == requestedType
                    && candidateSubtype == requestedSubtype

            guard mediaMatches else {
                return false
            }

            for parameter in mediaRange.parameters {
                guard let value = requested.parameters[
                    parameter.name.lowercased()
                ] else {
                    return false
                }

                let matches: Bool

                if parameter.name.caseInsensitiveCompare(
                    "charset"
                ) == .orderedSame {
                    matches =
                        value.caseInsensitiveCompare(
                            parameter.value
                        ) == .orderedSame
                } else {
                    matches =
                        value == parameter.value
                }

                guard matches else {
                    return false
                }
            }

            return true
        }
    }

    func queryRequestFailure(
        for request: HTTPRequest,
        route: Route
    ) -> HTTPResponse? {
        guard request.method == .query else {
            return nil
        }

        let contentType = request.headers.contentType?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard let contentType,
              !contentType.isEmpty
        else {
            return .badRequest(
                body: "QUERY requires Content-Type"
            )
        }

        guard let acceptedQuery = route.acceptedQuery else {
            return nil
        }

        guard queryContentType(
            contentType,
            isAcceptedBy: acceptedQuery
        ) else {
            return HTTPResponse(
                status: .unsupportedMediaType,
                body: "Unsupported query media type"
            )
        }

        return nil
    }

    func methodNotAllowedResponse(
        for request: HTTPRequest
    ) -> HTTPResponse {
        let allow = allowedMethods(
            for: request.path
        )
        .map(\.rawValue)
        .joined(
            separator: ", "
        )

        let response = HTTPResponse.methodNotAllowed(
            body: "Method \(request.method.rawValue) not allowed for \(request.path)",
            headers: [
                "Allow": allow,
            ]
        )

        return applyingQueryAdvertisement(
            to: response,
            for: request.path
        )
    }

    func optionsResponse(
        for path: HTTPPath
    ) -> HTTPResponse {
        let allow = allowedMethods(
            for: path
        )
        .map(\.rawValue)
        .joined(
            separator: ", "
        )

        let response = HTTPResponse.noContent(
            headers: [
                "Allow": allow,
            ]
        )

        return applyingQueryAdvertisement(
            to: response,
            for: path
        )
    }

    func fallback(
        for request: HTTPRequest
    ) -> HTTPResponse {
        let hasPath = routes.contains {
            $0.path == request.path
        }

        if hasPath {
            return methodNotAllowedResponse(
                for: request
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
        if let failure = queryRequestFailure(
            for: request,
            route: route
        ) {
            return applyingQueryAdvertisement(
                to: failure,
                for: request.path
            )
        }

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

        let response = await HTTPJSONCoding.$current.withValue(
            policy.coding
        ) {
            await handler(
                request,
                self
            )
        }

        return applyingQueryAdvertisement(
            to: response,
            for: request.path
        )
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
