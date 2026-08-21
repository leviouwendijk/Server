public protocol ServerOperation {
    associatedtype Contract:
        ServerContract

    associatedtype Input =
        Contract.Request

    associatedtype Output =
        Contract.Response

    static func input(
        from request: Contract.Request
    ) async throws -> Input

    static func execute(
        _ input: Input
    ) async throws -> Output

    static func response(
        from output: Output
    ) async throws -> Contract.Response
}

public extension ServerOperation
where
    Input == Contract.Request
{
    static func input(
        from request: Contract.Request
    ) async throws -> Input {
        request
    }
}

public extension ServerOperation
where
    Output == Contract.Response
{
    static func response(
        from output: Output
    ) async throws -> Contract.Response {
        output
    }
}
