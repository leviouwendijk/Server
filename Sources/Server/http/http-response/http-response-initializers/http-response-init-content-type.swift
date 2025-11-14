import Foundation

public extension HTTPResponse {
    mutating func contentType(_ type: String) {
        headers["Content-Type"] = type
    }
    
    static func withContentType(_ contentType: String, status: HTTPStatus = .ok, body: String = "") -> HTTPResponse {
        var resp = HTTPResponse(status: status, body: body)
        resp.headers["Content-Type"] = contentType
        return resp
    }
}
