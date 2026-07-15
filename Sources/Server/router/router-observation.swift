import HTTP

public extension Router {
    func observed(
        _ request: HTTPRequest
    ) async -> RouteResult {
        guard methods.contains(request.method) else {
            return RouteResult(
                response: .methodNotAllowed(
                    body: "Method \(request.method.rawValue) is disabled by server policy"
                ),
                pattern: nil,
                method: nil,
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
                pattern: route.path,
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
                pattern: route.path,
                method: route.method,
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
                pattern: route.path,
                method: route.method,
                synthetic: true
            )
        }

        let route = routes.first {
            $0.path == request.path
        }

        return RouteResult(
            response: fallback(
                for: request
            ),
            pattern: route?.path,
            method: route?.method,
            synthetic: false
        )
    }
}
