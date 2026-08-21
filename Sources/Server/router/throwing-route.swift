import HTTP
import Path

public extension Route {
    static func throwing(
        method: HTTPMethod,
        path: String,
        errors: RouteErrorMapper = .none,
        handler: @Sendable @escaping (
            HTTPRequest,
            Router
        ) async throws -> HTTPResponse
    ) -> Route {
        Route(
            method: method,
            path: path
        ) { request, router in
            do {
                return try await handler(
                    request,
                    router
                )
            } catch {
                return RouteErrorBoundary.response(
                    for: error,
                    phase: .operation,
                    scope: .raw,
                    errors: errors
                )
            }
        }
    }
}

public func route(
    _ method: HTTPMethod,
    path: String,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        HTTPRequest,
        Router
    ) async throws -> HTTPResponse
) -> Route {
    Route.throwing(
        method: method,
        path: path,
        errors: errors,
        handler: handler
    )
}

public func route(
    _ method: HTTPMethod,
    path: String,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        HTTPRequest
    ) async throws -> HTTPResponse
) -> Route {
    Route.throwing(
        method: method,
        path: path,
        errors: errors
    ) { request, _ in
        try await handler(
            request
        )
    }
}

public func route(
    _ method: HTTPMethod,
    _ components: String...,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        HTTPRequest,
        Router
    ) async throws -> HTTPResponse
) -> Route {
    Route.throwing(
        method: method,
        path: joinPath(
            components
        ),
        errors: errors,
        handler: handler
    )
}

public func route(
    _ method: HTTPMethod,
    _ components: String...,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        HTTPRequest
    ) async throws -> HTTPResponse
) -> Route {
    Route.throwing(
        method: method,
        path: joinPath(
            components
        ),
        errors: errors
    ) { request, _ in
        try await handler(
            request
        )
    }
}

public func route(
    _ method: HTTPMethod,
    _ path: StandardPath,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        HTTPRequest,
        Router
    ) async throws -> HTTPResponse
) -> Route {
    Route.throwing(
        method: method,
        path: path.render(
            as: .root,
            filetype: true
        ),
        errors: errors,
        handler: handler
    )
}

public func route(
    _ method: HTTPMethod,
    _ path: StandardPath,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        HTTPRequest
    ) async throws -> HTTPResponse
) -> Route {
    Route.throwing(
        method: method,
        path: path.render(
            as: .root,
            filetype: true
        ),
        errors: errors
    ) { request, _ in
        try await handler(
            request
        )
    }
}
