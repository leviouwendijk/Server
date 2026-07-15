import HTTP

public struct RouteResult: Sendable {
    public let response: HTTPResponse
    public let pattern: String?
    public let method: HTTPMethod?
    public let synthetic: Bool

    public init(
        response: HTTPResponse,
        pattern: String?,
        method: HTTPMethod?,
        synthetic: Bool
    ) {
        self.response = response
        self.pattern = pattern
        self.method = method
        self.synthetic = synthetic
    }
}
