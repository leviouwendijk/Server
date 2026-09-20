import HTTP

public extension Router {
    func observed(
        _ request: HTTPRequest
    ) async -> RouteResult {
        let routeAtPath = routes.first {
            $0.path == request.path
        }

        guard methods.contains(
            request.method
        ) else {
            return RouteResult(
                response: fallback(
                    for: request
                ),
                pattern: routeAtPath?.path.raw,
                method: routeAtPath?.method,
                synthetic: false
            )
        }

        if let route = exactRoute(
            for: request
        ) {
            return RouteResult(
                response: await run(
                    route,
                    request
                ),
                pattern: route.path.raw,
                method: route.method,
                synthetic: false
            )
        }

        if request.method == .options,
           let route = syntheticOptionsRoute(
               for: request
           ) {
            return RouteResult(
                response: await run(
                    route,
                    request
                ),
                pattern: route.path.raw,
                method: route.method,
                synthetic: true
            )
        }

        if request.method == .options,
           routeAtPath != nil {
            return RouteResult(
                response: optionsResponse(
                    for: request.path
                ),
                pattern: routeAtPath?.path.raw,
                method: .options,
                synthetic: true
            )
        }

        if request.method == .head,
           let route = syntheticHeadRoute(
               for: request
           ) {
            var response = await run(
                route,
                request
            )

            response.body = ""

            return RouteResult(
                response: response,
                pattern: route.path.raw,
                method: route.method,
                synthetic: true
            )
        }

        return RouteResult(
            response: fallback(
                for: request
            ),
            pattern: routeAtPath?.path.raw,
            method: routeAtPath?.method,
            synthetic: false
        )
    }
}
