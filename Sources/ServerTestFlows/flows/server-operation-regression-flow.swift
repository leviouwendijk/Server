import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverOperationRegressionFlow =
        TestFlow(
            "server.operation.regression",
            title:
                "Server operations separate transport contracts from executable input and output",
            tags: [
                "server",
                "operation",
                "contract",
                "input",
                "output",
                "typed",
                "regression",
            ]
        ) {
            Step(
                "identity defaults preserve simple Request-to-Response operations"
            ) {
                let response =
                    try await executeOperation(
                        EchoServerOperation.self,
                        request:
                            OperationRequest(
                                value:
                                    "operation-round-trip"
                            )
                    )

                try Expect.equal(
                    response.value,
                    "operation-round-trip",
                    "server-operation.identity.round-trip"
                )
            }

            Step(
                "operation can materialize Input and project Output independently of its contract"
            ) {
                let response =
                    try await executeOperation(
                        PipelineServerOperation.self,
                        request:
                            OperationRequest(
                                value:
                                    "operation-pipeline"
                            )
                    )

                try Expect.equal(
                    response.value,
                    "response:output:input:operation-pipeline",
                    "server-operation.pipeline.round-trip"
                )
            }
        }
}

private enum OperationContract:
    ServerContract
{
    typealias Request =
        OperationRequest

    typealias Response =
        OperationResponse
}

private struct OperationRequest:
    Requestable
{
    let value:
        String
}

private struct OperationResponse:
    Returnable
{
    let value:
        String
}

private enum EchoServerOperation:
    ServerOperation
{
    typealias Contract =
        OperationContract

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

private struct PipelineOperationInput:
    Sendable
{
    let value:
        String
}

private struct PipelineOperationOutput:
    Sendable
{
    let value:
        String
}

private enum PipelineServerOperation:
    ServerOperation
{
    typealias Contract =
        OperationContract

    typealias Input =
        PipelineOperationInput

    typealias Output =
        PipelineOperationOutput

    static func input(
        from request:
            Contract.Request,
        context _:
            HTTPRequest
    ) async throws
        -> Input
    {
        Input(
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
        Output(
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
        Contract.Response(
            value:
                "response:\(output.value)"
        )
    }
}

private func executeOperation<Operation>(
    _ type: Operation.Type,
    request:
        Operation.Contract.Request,
    context:
        HTTPRequest = HTTPRequest(
            method: .post,
            path: "/operation-regression",
            headers: [:],
            body: ""
        )
) async throws
    -> Operation.Contract.Response
where
    Operation:
        ServerOperation
{
    let input =
        try await type.input(
            from: request,
            context: context
        )

    let output =
        try await type.execute(
            input
        )

    return try await type.response(
        from: output
    )
}
