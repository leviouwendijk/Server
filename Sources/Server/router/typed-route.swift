import HTTP

public extension Route {
    static func typed<Request, Response>(
        _ endpoint: HTTPEndpoint,
        request: Request.Type,
        errors: RouteErrorMapper = .none,
        handler: @Sendable @escaping (
            Request,
            Router
        ) async throws -> Response
    ) -> Route
    where
        Request: HTTPRequestable,
        Response: HTTPRespondable
    {
        typed(
            Endpoint<Request, Response>(
                endpoint
            ),
            errors: errors,
            handler: handler
        )
    }
}

public extension Route {
    static func typed<Input, Output>(
        _ endpoint: Endpoint<Input, Output>,
        errors: RouteErrorMapper = .none,
        handler: @Sendable @escaping (
            Input,
            Router
        ) async throws -> Output
    ) -> Route
    where
        Input: HTTPRequestable,
        Output: HTTPRespondable
    {
        Route(
            method: endpoint.method,
            path: endpoint.path
        ) { httpRequest, router in
            let input: Input

            do {
                input = try Input.parse(
                    httpRequest
                )
            } catch {
                return RouteErrorBoundary.response(
                    for: error,
                    phase: .request,
                    scope: .typed,
                    errors: errors
                )
            }

            let output: Output

            do {
                output = try await handler(
                    input,
                    router
                )
            } catch {
                return RouteErrorBoundary.response(
                    for: error,
                    phase: .handler,
                    scope: .typed,
                    errors: errors
                )
            }

            do {
                return try output.response()
            } catch {
                return RouteErrorBoundary.response(
                    for: error,
                    phase: .response,
                    scope: .typed,
                    errors: errors
                )
            }
        }
    }
}

public func route<Input, Output>(
    _ endpoint: Endpoint<Input, Output>,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        Input,
        Router
    ) async throws -> Output
) -> Route
where
    Input: HTTPRequestable,
    Output: HTTPRespondable
{
    Route.typed(
        endpoint,
        errors: errors,
        handler: handler
    )
}

public func route<Input, Output>(
    _ endpoint: Endpoint<Input, Output>,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        Input
    ) async throws -> Output
) -> Route
where
    Input: HTTPRequestable,
    Output: HTTPRespondable
{
    Route.typed(
        endpoint,
        errors: errors
    ) { input, _ in
        try await handler(
            input
        )
    }
}

public func route<Request, Response>(
    _ endpoint: HTTPEndpoint,
    request: Request.Type,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        Request,
        Router
    ) async throws -> Response
) -> Route
where
    Request: HTTPRequestable,
    Response: HTTPRespondable
{
    Route.typed(
        endpoint,
        request: request,
        errors: errors,
        handler: handler
    )
}

public func route<Request, Response>(
    _ endpoint: HTTPEndpoint,
    request: Request.Type,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        Request
    ) async throws -> Response
) -> Route
where
    Request: HTTPRequestable,
    Response: HTTPRespondable
{
    Route.typed(
        endpoint,
        request: request,
        errors: errors
    ) { request, _ in
        try await handler(
            request
        )
    }
}

public func route<Request, Response>(
    _ request: Request.Type,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        Request,
        Router
    ) async throws -> Response
) -> Route
where
    Request: HTTPRequestableEndpoint,
    Response: HTTPRespondable
{
    Route.typed(
        Request.endpoint,
        request: request,
        errors: errors,
        handler: handler
    )
}

public func route<Request, Response>(
    _ request: Request.Type,
    errors: RouteErrorMapper = .none,
    handler: @Sendable @escaping (
        Request
    ) async throws -> Response
) -> Route
where
    Request: HTTPRequestableEndpoint,
    Response: HTTPRespondable
{
    Route.typed(
        Request.endpoint,
        request: request,
        errors: errors
    ) { request, _ in
        try await handler(
            request
        )
    }
}

public extension HTTPRequestableEndpoint {
    static func route<Response>(
        errors: RouteErrorMapper = .none,
        _ handler: @Sendable @escaping (
            Self,
            Router
        ) async throws -> Response
    ) -> Route
    where Response: HTTPRespondable {
        Route.typed(
            Self.endpoint,
            request: Self.self,
            errors: errors,
            handler: handler
        )
    }

    static func route<Response>(
        errors: RouteErrorMapper = .none,
        _ handler: @Sendable @escaping (
            Self
        ) async throws -> Response
    ) -> Route
    where Response: HTTPRespondable {
        Route.typed(
            Self.endpoint,
            request: Self.self,
            errors: errors
        ) { request, _ in
            try await handler(
                request
            )
        }
    }
}
