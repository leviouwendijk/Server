public protocol ServerOperation {
    associatedtype Contract:
        ServerContract

    static func execute(
        _ request: Contract.Request
    ) async throws -> Contract.Response
}
