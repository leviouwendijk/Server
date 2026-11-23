import Foundation
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

            // HEAD reports the GET representation's length without sending it.
            if response.headers.get(
                HTTPConstants.contentLengthHeader
            ) == nil {
                response.headers.set(
                    HTTPConstants.contentLengthHeader,
                    "\(response.bodyData.count)"
                )
            }

            response.bodyData = Data()

            return RouteResult(
                response: response,
                pattern: route.path.raw,
                method: route.method,
                synthetic: true
            )
        }

        if routeAtPath == nil,
           let unmatched,
           let response = await unmatched(
               request
           ) {
            return RouteResult(
                response: response,
                pattern: nil,
                method: request.method,
                synthetic: false
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
