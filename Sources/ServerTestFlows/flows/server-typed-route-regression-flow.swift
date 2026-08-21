import Foundation
import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverTypedRouteRegressionFlow = TestFlow(
        "server.typed-route.regression",
        title: "Typed endpoint routes remain ordinary Server routes with fail-closed transport handling",
        tags: [
            "server",
            "route",
            "typed",
            "endpoint",
            "transport",
            "regression",
        ]
    ) {
        Step("model endpoint produces ordinary route metadata") {
            let typedRoute = TypedRouteRequest.route { request in
                TypedRouteResponse(
                    echoedValue: request.value
                )
            }

            try Expect.equal(
                typedRoute.method,
                .post,
                "typed-route.metadata.method"
            )

            try Expect.equal(
                typedRoute.path.raw,
                "/typed/models",
                "typed-route.metadata.path"
            )
        }

        Step("typed route parses request and renders typed response") {
            let router = Router(
                routes: [
                    TypedRouteRequest.route { request in
                        TypedRouteResponse(
                            echoedValue: request.value
                        )
                    },
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/typed/models",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: """
                    {
                        "value": "round-trip"
                    }
                    """
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "typed-route.round-trip.status"
            )

            let decodedResponse = try JSONDecoder().decode(
                TypedRouteResponse.self,
                from: Data(
                    response.body.utf8
                )
            )

            try Expect.equal(
                decodedResponse.echoedValue,
                "round-trip",
                "typed-route.round-trip.body"
            )

            try Expect.equal(
                response.header(
                    "Content-Type"
                ),
                "application/json; charset=utf-8",
                "typed-route.round-trip.content-type"
            )
        }

        Step("generic endpoint drives typed route input and output") {
            let endpoint = Endpoint<
                TypedRouteExplicitRequest,
                TypedRouteResponse
            >(
                method: .put,
                "typed",
                "override"
            )

            let typedRoute = route(
                endpoint
            ) { request in
                TypedRouteResponse(
                    echoedValue: request.value
                )
            }

            try Expect.equal(
                typedRoute.method,
                .put,
                "typed-route.override.method"
            )

            try Expect.equal(
                typedRoute.path.raw,
                "/typed/override",
                "typed-route.override.path"
            )

            let router = Router(
                routes: [
                    typedRoute,
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .put,
                    path: "/typed/override",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: """
                    {
                        "value": "generic-round-trip"
                    }
                    """
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "typed-route.override.round-trip.status"
            )

            let decodedResponse = try JSONDecoder().decode(
                TypedRouteResponse.self,
                from: Data(
                    response.body.utf8
                )
            )

            try Expect.equal(
                decodedResponse.echoedValue,
                "generic-round-trip",
                "typed-route.override.round-trip.body"
            )
        }

        Step("endpoint-aware model can use explicit route override") {
            let typedRoute = route(
                HTTPEndpoint(
                    method: .patch,
                    "alternate",
                    "models"
                ),
                request: TypedRouteRequest.self
            ) { request in
                TypedRouteResponse(
                    echoedValue: request.value
                )
            }

            try Expect.equal(
                typedRoute.method,
                .patch,
                "typed-route.reachable-override.method"
            )

            try Expect.equal(
                typedRoute.path.raw,
                "/alternate/models",
                "typed-route.reachable-override.path"
            )

            try Expect.equal(
                TypedRouteRequest.endpoint.path,
                "/typed/models",
                "typed-route.reachable-override.model-unchanged"
            )
        }

        Step("router-aware typed handler remains available") {
            let router = Router(
                routes: [
                    TypedRouteRequest.route { request, _ in
                        TypedRouteResponse(
                            echoedValue: request.value
                        )
                    },
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/typed/models",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: """
                    {
                        "value": "router-aware"
                    }
                    """
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "typed-route.router-aware.status"
            )

            let decodedResponse = try JSONDecoder().decode(
                TypedRouteResponse.self,
                from: Data(
                    response.body.utf8
                )
            )

            try Expect.equal(
                decodedResponse.echoedValue,
                "router-aware",
                "typed-route.router-aware.body"
            )
        }

        Step("typed route remains middleware composable") {
            let typedRoute = TypedRouteRequest.route { request in
                TypedRouteResponse(
                    echoedValue: request.value
                )
            }
            .use(
                TypedRouteHeaderMiddleware()
            )

            let router = Router(
                routes: [
                    typedRoute,
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/typed/models",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: """
                    {
                        "value": "middleware"
                    }
                    """
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "typed-route.middleware.status"
            )

            try Expect.equal(
                response.header(
                    "X-Typed-Route"
                ),
                "applied",
                "typed-route.middleware.header"
            )
        }

        Step("malformed typed request fails closed as bad request") {
            let router = Router(
                routes: [
                    TypedRouteRequest.route { request in
                        TypedRouteResponse(
                            echoedValue: request.value
                        )
                    },
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/typed/models",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: "not-json"
                )
            )

            try Expect.equal(
                response.status.code,
                400,
                "typed-route.parse-failure.status"
            )

            try Expect.equal(
                response.body,
                "Bad Request",
                "typed-route.parse-failure.body"
            )

            try Expect.equal(
                response.failure?.code,
                "server.typed_route.request",
                "typed-route.parse-failure.code"
            )
        }

        Step("unknown typed handler failure fails closed as internal error") {
            let router = Router(
                routes: [
                    TypedRouteRequest.route { _ -> TypedRouteResponse in
                        throw TypedRouteTestError.handler
                    },
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/typed/models",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: """
                    {
                        "value": "handler-error"
                    }
                    """
                )
            )

            try Expect.equal(
                response.status.code,
                500,
                "typed-route.handler-failure.status"
            )

            try Expect.equal(
                response.body,
                "Internal Server Error",
                "typed-route.handler-failure.body"
            )

            try Expect.equal(
                response.failure?.code,
                "server.typed_route.operation",
                "typed-route.handler-failure.code"
            )
        }

        Step("typed response construction failure fails closed as internal error") {
            let router = Router(
                routes: [
                    TypedRouteRequest.route { _ in
                        TypedRouteFailingResponse()
                    },
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/typed/models",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: """
                    {
                        "value": "response-error"
                    }
                    """
                )
            )

            try Expect.equal(
                response.status.code,
                500,
                "typed-route.response-failure.status"
            )

            try Expect.equal(
                response.body,
                "Internal Server Error",
                "typed-route.response-failure.body"
            )

            try Expect.equal(
                response.failure?.code,
                "server.typed_route.response",
                "typed-route.response-failure.code"
            )
        }

        Step("reportable handler error preserves explicit public response") {
            let router = Router(
                routes: [
                    TypedRouteRequest.route { _ -> TypedRouteResponse in
                        throw TypedRoutePublicError.rejected
                    },
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/typed/models",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: """
                    {
                        "value": "reportable-error"
                    }
                    """
                )
            )

            try Expect.equal(
                response.status.code,
                403,
                "typed-route.reportable.status"
            )

            try Expect.equal(
                response.body,
                "Typed route request rejected",
                "typed-route.reportable.public-body"
            )

            try Expect.equal(
                response.failure?.code,
                "typed-route.public.rejected",
                "typed-route.reportable.failure-code"
            )

            try Expect.equal(
                response.failure?.message,
                "Internal typed route rejection detail",
                "typed-route.reportable.internal-message"
            )
        }
    }
}

private struct TypedRouteRequest:
    Decodable,
    Sendable,
    HTTPReachable
{
    static let endpoint = HTTPEndpoint(
        method: .post,
        "typed",
        "models"
    )

    let value: String
}

private struct TypedRouteExplicitRequest:
    Requestable
{
    let value: String
}

private struct TypedRouteResponse:
    Returnable
{
    let echoedValue: String
}

private struct TypedRouteFailingResponse:
    Sendable,
    HTTPRespondable
{
    func response(
        status: HTTPStatus
    ) throws -> HTTPResponse {
        throw TypedRouteTestError.response
    }
}

private struct TypedRouteHeaderMiddleware: Middleware {
    let name = "typed-route-header"

    func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (
            HTTPRequest,
            Router
        ) async -> HTTPResponse
    ) async -> HTTPResponse {
        var response = await next(
            request,
            router
        )

        response.setHeader(
            "X-Typed-Route",
            "applied"
        )

        return response
    }
}

private enum TypedRouteTestError: Error {
    case handler
    case response
}

private enum TypedRoutePublicError:
    Error,
    HTTPReportableError
{
    case rejected

    var httpStatus: HTTPStatus {
        .forbidden
    }

    var publicMessage: String {
        "Typed route request rejected"
    }

    var httpFailure: HTTPFailure {
        HTTPFailure(
            code: "typed-route.public.rejected",
            kind: .authorization,
            message: "Internal typed route rejection detail"
        )
    }
}
