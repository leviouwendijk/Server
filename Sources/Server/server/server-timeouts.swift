public struct ServerTimeouts: Sendable, Hashable, Equatable {
    public let idle: Duration
    public let headers: Duration
    public let content: Duration

    /// Maximum time the server waits for route execution to produce a response.
    ///
    /// On expiry the server returns 503 and requests cancellation of the route
    /// task. Cancellation of application work remains cooperative.
    public let execution: Duration?

    /// Maximum time one response may take to be handed to the client. A client that
    /// stops reading is disconnected instead of holding the connection.
    public let send: Duration

    /// Grace period for in-flight requests when the process is asked to stop.
    public let shutdown: Duration

    public init(
        idle: Duration = .seconds(60),
        headers: Duration = .seconds(10),
        content: Duration = .seconds(60),
        execution: Duration? = nil,
        send: Duration = .seconds(30),
        shutdown: Duration = .seconds(10)
    ) {
        self.idle = idle
        self.headers = headers
        self.content = content
        self.execution = execution
        self.send = send
        self.shutdown = shutdown
    }

    public static let `default` = Self()
}
