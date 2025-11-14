import Foundation

public extension HTTPResponse {
    /// Create an HTML response
    static func html(_ body: String, status: HTTPStatus = .ok, headers: [String: String] = [:]) -> HTTPResponse {
        var h = headers
        h["Content-Type"] = "text/html; charset=utf-8"
        return HTTPResponse(status: status, headers: h, body: body)
    }
}
