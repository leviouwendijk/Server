import Foundation
import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverOperationRouteRegressionFlow =
        TestFlow(
            "server.operation-route.regression",
            title:
                "Server operation routes preserve the full Request-Input-Operation-Output-Response pipeline",
            tags: [
                "server",
                "operation",
                "route",
                "contract",
                "input",
                "output",
                "error",
                "typed",
                "regression",
            ]
        ) {
            Step(
                "identity operation route parses contract request and renders contract response"
            ) {
                let operationRoute =
                    route(
                        HTTPEndpoint(
                            method: .post,
                            "operations",
                            "echo"
                        ),
                        operation:
                            OperationRouteEcho.self
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

                let router =
                    Router(
                        routes: [
                            operationRoute,
                        ]
                    )

                let response =
                    await router.route(
                        operationRouteRequest(
                            path:
                                "/operations/echo",
                            value:
                                "operation-route-round-trip"
                        )
                    )

                try Expect.equal(
                    response.status.code,
                    200,
                    "server-operation-route.round-trip.status"
                )

                let decoded =
                    try JSONDecoder()
                        .decode(
                            OperationRouteResponse.self,
                            from:
                                Data(
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
                "default error mapping now targets operation execution"
            ) {
                let errors =
                    RouteErrorMapper(
                        .handling(
                            OperationRouteFailure.self
                        ) { _ in
                            HTTPResponse(
                                status: .badRequest,
                                body:
                                    "Mapped operation failure"
                            )
                        }
                    )

                let router =
                    Router(
                        routes: [
                            route(
                                HTTPEndpoint(
                                    method: .post,
                                    "operations",
                                    "failure"
                                ),
                                operation:
                                    OperationRouteFailing.self,
                                errors:
                                    errors
                            ),
                        ]
                    )

                let response =
                    await router.route(
                        operationRouteRequest(
                            path:
                                "/operations/failure",
                            value:
                                "reject"
                        )
                    )

                try Expect.equal(
                    response.status.code,
                    400,
                    "server-operation-route.operation-mapping.status"
                )

                try Expect.equal(
                    response.body,
                    "Mapped operation failure",
                    "server-operation-route.operation-mapping.body"
                )
            }

            Step(
                "input operation and output failures retain distinct route phases"
            ) {
                let errors =
                    RouteErrorMapper(
                        .handling(
                            OperationPipelineFailure.self,
                            phase: .input
                        ) { _ in
                            HTTPResponse(
                                status:
                                    .unprocessableEntity,
                                body:
                                    "Mapped input failure"
                            )
                        },
                        .handling(
                            OperationPipelineFailure.self,
                            phase: .operation
                        ) { _ in
                            HTTPResponse(
                                status:
                                    .conflict,
                                body:
                                    "Mapped operation failure"
                            )
                        },
                        .handling(
                            OperationPipelineFailure.self,
                            phase: .output
                        ) { _ in
                            HTTPResponse(
                                status:
                                    .internalServerError,
                                body:
                                    "Mapped output failure"
                            )
                        }
                    )

                let router =
                    Router(
                        routes: [
                            route(
                                HTTPEndpoint(
                                    method: .post,
                                    "operations",
                                    "pipeline"
                                ),
                                operation:
                                    OperationRoutePipeline.self,
                                errors:
                                    errors
                            ),
                        ]
                    )

                let inputResponse =
                    await router.route(
                        operationRouteRequest(
                            path:
                                "/operations/pipeline",
                            value:
                                "fail-input"
                        )
                    )

                try Expect.equal(
                    inputResponse.status.code,
                    422,
                    "server-operation-route.input-phase.status"
                )

                try Expect.equal(
                    inputResponse.body,
                    "Mapped input failure",
                    "server-operation-route.input-phase.body"
                )

                let operationResponse =
                    await router.route(
                        operationRouteRequest(
                            path:
                                "/operations/pipeline",
                            value:
                                "fail-operation"
                        )
                    )

                try Expect.equal(
                    operationResponse.status.code,
                    409,
                    "server-operation-route.operation-phase.status"
                )

                try Expect.equal(
                    operationResponse.body,
                    "Mapped operation failure",
                    "server-operation-route.operation-phase.body"
                )

                let outputResponse =
                    await router.route(
                        operationRouteRequest(
                            path:
                                "/operations/pipeline",
                            value:
                                "fail-output"
                        )
                    )

                try Expect.equal(
                    outputResponse.status.code,
                    500,
                    "server-operation-route.output-phase.status"
                )

                try Expect.equal(
                    outputResponse.body,
                    "Mapped output failure",
                    "server-operation-route.output-phase.body"
                )
            }

            Step(
                "successful rich operation route applies Input and Output projections"
            ) {
                let router =
                    Router(
                        routes: [
                            route(
                                HTTPEndpoint(
                                    method: .post,
                                    "operations",
                                    "pipeline"
                                ),
                                operation:
                                    OperationRoutePipeline.self
                            ),
                        ]
                    )

                let response =
                    await router.route(
                        operationRouteRequest(
                            path:
                                "/operations/pipeline",
                            value:
                                "success"
                        )
                    )

                try Expect.equal(
                    response.status.code,
                    200,
                    "server-operation-route.pipeline.status"
                )

                let decoded =
                    try JSONDecoder()
                        .decode(
                            OperationRouteResponse.self,
                            from:
                                Data(
                                    response.body.utf8
                                )
                        )

                try Expect.equal(
                    decoded.value,
                    "response:output:input:success",
                    "server-operation-route.pipeline.body"
                )
            }

            Step(
                "canonical route phases expose the five architectural boundaries"
            ) {
                try Expect.equal(
                    RouteErrorPhase.request.rawValue,
                    "request",
                    "server-route-phase.request"
                )

                try Expect.equal(
                    RouteErrorPhase.input.rawValue,
                    "input",
                    "server-route-phase.input"
                )

                try Expect.equal(
                    RouteErrorPhase.operation.rawValue,
                    "operation",
                    "server-route-phase.operation"
                )

                try Expect.equal(
                    RouteErrorPhase.output.rawValue,
                    "output",
                    "server-route-phase.output"
                )

                try Expect.equal(
                    RouteErrorPhase.response.rawValue,
                    "response",
                    "server-route-phase.response"
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
    let value:
        String
}

private struct OperationRouteResponse:
    Returnable
{
    let value:
        String
}

private enum OperationRouteEcho:
    ServerOperation
{
    typealias Contract =
        OperationRouteContract

    static func execute(
        _ request:
            Contract.Request
    ) async throws
        -> Contract.Response
    {
        Contract.Response(
            value:
                request.value
        )
    }
}

private enum OperationRouteFailing:
    ServerOperation
{
    typealias Contract =
        OperationRouteContract

    static func execute(
        _ request:
            Contract.Request
    ) async throws
        -> Contract.Response
    {
        _ = request

        throw OperationRouteFailure
            .rejected
    }
}

private enum OperationRouteFailure:
    Error
{
    case rejected
}

private struct OperationRoutePipelineInput:
    Sendable
{
    let value:
        String
}

private struct OperationRoutePipelineOutput:
    Sendable
{
    let value:
        String
}

private enum OperationRoutePipeline:
    ServerOperation
{
    typealias Contract =
        OperationRouteContract

    typealias Input =
        OperationRoutePipelineInput

    typealias Output =
        OperationRoutePipelineOutput

    static func input(
        from request:
            Contract.Request
    ) async throws
        -> Input
    {
        if request.value ==
            "fail-input"
        {
            throw OperationPipelineFailure
                .input
        }

        return Input(
            value:
                "input:\(request.value)"
        )
    }

    static func execute(
        _ input:
            Input
    ) async throws
        -> Output
    {
        if input.value ==
            "input:fail-operation"
        {
            throw OperationPipelineFailure
                .operation
        }

        return Output(
            value:
                "output:\(input.value)"
        )
    }

    static func response(
        from output:
            Output
    ) async throws
        -> Contract.Response
    {
        if output.value ==
            "output:input:fail-output"
        {
            throw OperationPipelineFailure
                .output
        }

        return Contract.Response(
            value:
                "response:\(output.value)"
        )
    }
}

private enum OperationPipelineFailure:
    Error
{
    case input
    case operation
    case output
}

private func operationRouteRequest(
    path: String,
    value: String
) -> HTTPRequest {
    HTTPRequest(
        method: .post,
        path: path,
        headers: [
            "Content-Type":
                "application/json",
        ],
        body:
            """
            {
                "value": "\(value)"
            }
            """
    )
}
