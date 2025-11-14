import Foundation

public extension HTTPResponse {
    /// Create a plain text response
    static func text(_ body: String, status: HTTPStatus = .ok, headers: [String: String] = [:]) -> HTTPResponse {
        var h = headers
        h["Content-Type"] = "text/plain; charset=utf-8"
        return HTTPResponse(status: status, headers: h, body: body)
    }
}
