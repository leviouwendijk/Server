import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverRouteErrorMappingRegressionFlow = TestFlow(
        "server.route-error-mapping.regression",
        title: "Route-local error mapping composes with typed and raw throwing routes",
        tags: [
            "server",
            "route",
            "error",
            "mapping",
            "typed",
            "regression",
        ]
    ) {
        Step("typed handler maps domain error locally") {
            let errors = RouteErrorMapper(
                .handling(
                    RouteErrorMappingTestError.self
                ) { error in
                    switch error {
                    case .invalidCredentials:
                        HTTPResponse(
                            status: .unauthorized,
                            body: "Invalid credentials"
                        )

                    case .conflict:
                        HTTPResponse(
                            status: .conflict,
                            body: "Conflict"
                        )

                    case .invalidInput:
                        HTTPResponse(
                            status: .unprocessableEntity,
                            body: "Invalid input"
                        )
                    }
                }
            )

            let router = Router(
                routes: [
                    RouteErrorMappingRequest.route(
                        errors: errors
                    ) { _ -> RouteErrorMappingResponse in
                        throw RouteErrorMappingTestError
                            .invalidCredentials
                    },
                ]
            )

            let response = await router.route(
                routeErrorMappingRequest(
                    path: "/errors/typed"
                )
            )

            try Expect.equal(
                response.status.code,
                401,
                "route-error-mapping.typed.status"
            )

            try Expect.equal(
                response.body,
                "Invalid credentials",
                "route-error-mapping.typed.body"
            )
        }

        Step("raw throwing route uses same domain error mapper") {
            let errors = RouteErrorMapper(
                .handling(
                    RouteErrorMappingTestError.self
                ) { error in
                    switch error {
                    case .conflict:
                        HTTPResponse(
                            status: .conflict,
                            body: "Raw conflict"
                        )

                    case .invalidCredentials,
                         .invalidInput:
                        HTTPResponse(
                            status: .badRequest,
                            body: "Bad request"
                        )
                    }
                }
            )

            let router = Router(
                routes: [
                    route(
                        .post,
                        "errors",
                        "raw",
                        errors: errors
                    ) { _ in
                        throw RouteErrorMappingTestError
                            .conflict
                    },
                ]
            )

            let response = await router.route(
                routeErrorMappingRequest(
                    path: "/errors/raw"
                )
            )

            try Expect.equal(
                response.status.code,
                409,
                "route-error-mapping.raw.status"
            )

            try Expect.equal(
                response.body,
                "Raw conflict",
                "route-error-mapping.raw.body"
            )
        }

        Step("request parsing can have phase-specific mapping") {
            let errors = RouteErrorMapper(
                .handling(
                    RouteErrorMappingTestError.self,
                    phase: .request
                ) { _ in
                    HTTPResponse(
                        status: .unprocessableEntity,
                        body: "Request could not be interpreted"
                    )
                }
            )

            let router = Router(
                routes: [
                    RouteErrorParsingRequest.route(
                        errors: errors
                    ) { _ in
                        RouteErrorMappingResponse(
                            value: "unreachable"
                        )
                    },
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/errors/parsing"
                )
            )

            try Expect.equal(
                response.status.code,
                422,
                "route-error-mapping.parsing.status"
            )

            try Expect.equal(
                response.body,
                "Request could not be interpreted",
                "route-error-mapping.parsing.body"
            )
        }

        Step("endpoint-local mapping overrides reportable default") {
            let errors = RouteErrorMapper(
                .handling(
                    RouteErrorMappingPublicError.self
                ) { _ in
                    HTTPResponse(
                        status: .conflict,
                        body: "Endpoint-specific response"
                    )
                }
            )

            let router = Router(
                routes: [
                    RouteErrorMappingRequest.route(
                        errors: errors
                    ) { _ -> RouteErrorMappingResponse in
                        throw RouteErrorMappingPublicError
                            .rejected
                    },
                ]
            )

            let response = await router.route(
                routeErrorMappingRequest(
                    path: "/errors/typed"
                )
            )

            try Expect.equal(
                response.status.code,
                409,
                "route-error-mapping.override.status"
            )

            try Expect.equal(
                response.body,
                "Endpoint-specific response",
                "route-error-mapping.override.body"
            )
        }

        Step("unmapped reportable error retains its declared behavior") {
            let router = Router(
                routes: [
                    RouteErrorMappingRequest.route {
                        _ -> RouteErrorMappingResponse in

                        throw RouteErrorMappingPublicError
                            .rejected
                    },
                ]
            )

            let response = await router.route(
                routeErrorMappingRequest(
                    path: "/errors/typed"
                )
            )

            try Expect.equal(
                response.status.code,
                403,
                "route-error-mapping.reportable.status"
            )

            try Expect.equal(
                response.body,
                "Default public rejection",
                "route-error-mapping.reportable.body"
            )

            try Expect.equal(
                response.failure?.code,
                "route-error-mapping.default",
                "route-error-mapping.reportable.failure"
            )
        }

        Step("unmapped raw error still fails closed") {
            let router = Router(
                routes: [
                    route(
                        .post,
                        "errors",
                        "unknown"
                    ) { _ in
                        throw RouteErrorMappingUnknownError()
                    },
                ]
            )

            let response = await router.route(
                routeErrorMappingRequest(
                    path: "/errors/unknown"
                )
            )

            try Expect.equal(
                response.status.code,
                500,
                "route-error-mapping.unknown.status"
            )

            try Expect.equal(
                response.body,
                "Internal Server Error",
                "route-error-mapping.unknown.body"
            )

            try Expect.equal(
                response.failure?.code,
                "server.route.operation",
                "route-error-mapping.unknown.failure"
            )
        }
    }
}

private struct RouteErrorMappingRequest:
    Decodable,
    Sendable,
    HTTPReachable
{
    static let endpoint = HTTPEndpoint(
        method: .post,
        "errors",
        "typed"
    )

    let value: String
}

private struct RouteErrorParsingRequest:
    Sendable,
    HTTPReachable
{
    static let endpoint = HTTPEndpoint(
        method: .post,
        "errors",
        "parsing"
    )

    static func parse(
        _ request: HTTPRequest
    ) throws -> Self {
        throw RouteErrorMappingTestError.invalidInput
    }
}

private struct RouteErrorMappingResponse:
    Encodable,
    Sendable,
    HTTPRespondable
{
    let value: String
}

private enum RouteErrorMappingTestError: Error {
    case invalidCredentials
    case conflict
    case invalidInput
}

private enum RouteErrorMappingPublicError:
    Error,
    HTTPReportableError
{
    case rejected

    var httpStatus: HTTPStatus {
        .forbidden
    }

    var publicMessage: String {
        "Default public rejection"
    }

    var httpFailure: HTTPFailure {
        HTTPFailure(
            code: "route-error-mapping.default",
            kind: .authorization,
            message: "Internal default rejection"
        )
    }
}

private struct RouteErrorMappingUnknownError: Error {}

private func routeErrorMappingRequest(
    path: String
) -> HTTPRequest {
    HTTPRequest(
        method: .post,
        path: path,
        headers: [
            "Content-Type": "application/json",
        ],
        body: """
        {
            "value": "test"
        }
        """
    )
}
