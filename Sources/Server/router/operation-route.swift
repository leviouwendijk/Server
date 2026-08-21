import HTTP

public func route<Operation>(
    _ endpoint: HTTPEndpoint,
    operation _: Operation.Type,
    errors: RouteErrorMapper = .none
) -> Route
where
    Operation:
        ServerOperation,
    Operation:
        SendableMetatype
{
    Route.typed(
        endpoint,
        request: Operation.Contract.Request.self,
        errors: errors
    ) { request, _ in
        try await Operation.execute(
            request
        )
    }
}
