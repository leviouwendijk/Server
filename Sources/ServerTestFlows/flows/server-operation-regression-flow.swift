import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverOperationRegressionFlow = TestFlow(
        "server.operation.regression",
        title: "Server operations execute typed server contracts without transport ownership",
        tags: [
            "server",
            "operation",
            "contract",
            "typed",
            "regression",
        ]
    ) {
        Step(
            "generic operation consumer executes contract request into contract response"
        ) {
            let response = try await executeOperation(
                EchoServerOperation.self,
                request: OperationRequest(
                    value: "operation-round-trip"
                )
            )

            try Expect.equal(
                response.value,
                "operation-round-trip",
                "server-operation.generic.round-trip"
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
    let value: String
}

private struct OperationResponse:
    Returnable
{
    let value: String
}

private enum EchoServerOperation:
    ServerOperation
{
    typealias Contract =
        OperationContract

    static func execute(
        _ request: Contract.Request
    ) async throws -> Contract.Response {
        Contract.Response(
            value: request.value
        )
    }
}

private func executeOperation<Operation>(
    _ type: Operation.Type,
    request: Operation.Contract.Request
) async throws -> Operation.Contract.Response
where
    Operation:
        ServerOperation
{
    try await type.execute(
        request
    )
}
