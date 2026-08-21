import Foundation
import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverOperationRouteRegressionFlow = TestFlow(
        "server.operation-route.regression",
        title: "Server operations mount through existing typed route transport",
        tags: [
            "server",
            "operation",
            "route",
            "contract",
            "typed",
            "regression",
        ]
    ) {
        Step(
            "operation route parses contract request and renders contract response"
        ) {
            let operationRoute = route(
                HTTPEndpoint(
                    method: .post,
                    "operations",
                    "echo"
                ),
                operation: OperationRouteEcho.self
            )

            try Expect.equal(
                operationRoute.method,
                .post,
                "server-operation-route.metadata.method"
            )

            try Expect.equal(
                operationRoute.path.raw,
                "/operations/echo",
                "server-operation-route.metadata.path"
            )

            let router = Router(
                routes: [
                    operationRoute,
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/operations/echo",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: """
                    {
                        "value": "operation-route-round-trip"
                    }
                    """
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "server-operation-route.round-trip.status"
            )

            let decoded = try JSONDecoder().decode(
                OperationRouteResponse.self,
                from: Data(
                    response.body.utf8
                )
            )

            try Expect.equal(
                decoded.value,
                "operation-route-round-trip",
                "server-operation-route.round-trip.body"
            )
        }

        Step(
            "operation route forwards handler error mapping"
        ) {
            let errors = RouteErrorMapper(
                .handling(
                    OperationRouteFailure.self
                ) { _ in
                    HTTPResponse(
                        status: .badRequest,
                        body: "Mapped operation failure"
                    )
                }
            )

            let operationRoute = route(
                HTTPEndpoint(
                    method: .post,
                    "operations",
                    "failure"
                ),
                operation: OperationRouteFailing.self,
                errors: errors
            )

            let router = Router(
                routes: [
                    operationRoute,
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/operations/failure",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: """
                    {
                        "value": "reject"
                    }
                    """
                )
            )

            try Expect.equal(
                response.status.code,
                400,
                "server-operation-route.error-mapping.status"
            )

            try Expect.equal(
                response.body,
                "Mapped operation failure",
                "server-operation-route.error-mapping.body"
            )
        }
    }
}

private enum OperationRouteContract:
    ServerContract
{
    typealias Request =
        OperationRouteRequest

    typealias Response =
        OperationRouteResponse
}

private struct OperationRouteRequest:
    Requestable
{
    let value: String
}

private struct OperationRouteResponse:
    Returnable
{
    let value: String
}

private enum OperationRouteEcho:
    ServerOperation
{
    typealias Contract =
        OperationRouteContract

    static func execute(
        _ request: Contract.Request
    ) async throws -> Contract.Response {
        Contract.Response(
            value: request.value
        )
    }
}

private enum OperationRouteFailing:
    ServerOperation
{
    typealias Contract =
        OperationRouteContract

    static func execute(
        _ request: Contract.Request
    ) async throws -> Contract.Response {
        _ = request

        throw OperationRouteFailure.rejected
    }
}

private enum OperationRouteFailure:
    Error
{
    case rejected
}
