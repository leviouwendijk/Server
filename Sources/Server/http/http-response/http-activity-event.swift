import Foundation

public struct HTTPActivityEvent: Sendable {
    public let timestamp: Date
    public let method: HTTPMethod
    public let path: String
    public let status: HTTPStatus
    public let clientDescription: String?
}

public typealias HTTPActivityCallback = @Sendable (_ event: HTTPActivityEvent) -> Void
