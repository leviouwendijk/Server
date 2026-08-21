import HTTP

public func route<Operation>(
    _ endpoint: HTTPEndpoint,
    operation _: Operation.Type,
    errors:
        RouteErrorMapper = .none
) -> Route
where
    Operation:
        ServerOperation,
    Operation:
        SendableMetatype
{
    Route.typed(
        endpoint,
        request:
            Operation.Contract.Request.self,
        errors:
            errors
    ) { request, _ in
        let input:
            Operation.Input

        do {
            input =
                try await Operation.input(
                    from: request
                )
        } catch {
            throw RoutePhasedError(
                error,
                phase: .input
            )
        }

        let output:
            Operation.Output

        do {
            output =
                try await Operation.execute(
                    input
                )
        } catch {
            throw RoutePhasedError(
                error,
                phase: .operation
            )
        }

        do {
            return try await Operation.response(
                from: output
            )
        } catch {
            throw RoutePhasedError(
                error,
                phase: .output
            )
        }
    }
}
