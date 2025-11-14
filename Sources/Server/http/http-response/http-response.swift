import Foundation

public struct HTTPResponse: Sendable {
    public let status: HTTPStatus
    public var headers: [String: String]
    public var body: String

    public init(status: HTTPStatus, headers: [String: String] = [:], body: String = "") {
        self.status = status
        self.headers = headers
        self.body = body
    }
}
