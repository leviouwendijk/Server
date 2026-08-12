public struct ServerTimeouts: Sendable, Hashable, Equatable {
    public let idle: Duration
    public let headers: Duration
    public let content: Duration

    /// Maximum time the server waits for route execution to produce a response.
    ///
    /// On expiry the server returns 504 and requests cancellation of the route
    /// task. Cancellation of application work remains cooperative.
    public let execution: Duration?

    public init(
        idle: Duration = .seconds(60),
        headers: Duration = .seconds(10),
        content: Duration = .seconds(60),
        execution: Duration? = nil
    ) {
        self.idle = idle
        self.headers = headers
        self.content = content
        self.execution = execution
    }

    public static let `default` = Self()
}
