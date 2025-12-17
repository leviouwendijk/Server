import Foundation

public struct HTTPActivityEvent: Sendable {
    public let serviceName: String

    /// Time at which we logged the event.
    public let timestamp: Date

    public let method: HTTPMethod
    public let path: String
    public let status: HTTPStatus

    /// Optional metadata.
    public let clientDescription: String?   // e.g. connection.endpoint
    public let requestId: String?           // from header, if present
    public let userAgent: String?           // from header, if present
    public let duration: TimeInterval?      // seconds from request start to response
    
    public init(
        serviceName: String? = nil,
        timestamp: Date,
        method: HTTPMethod,
        path: String,
        status: HTTPStatus,
        clientDescription: String?,
        requestId: String?,
        userAgent: String?,
        duration: TimeInterval?
    ) {
        self.serviceName = serviceName ?? "<< 'config.name' ('ServerConfig') or 'APP_NAME' has not been set >>"
        self.timestamp = timestamp
        self.method = method
        self.path = path
        self.status = status
        self.clientDescription = clientDescription
        self.requestId = requestId
        self.userAgent = userAgent
        self.duration = duration
    }
}

public typealias HTTPActivityCallback = @Sendable (_ event: HTTPActivityEvent) -> Void
