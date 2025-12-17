import Foundation
// import plate
import Methods

public extension HTTPResponse {
    /// Create a 200 OK response
    static func ok(body: String = "", headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: .ok, headers: headers, body: body)
    }
    
    /// Create a 201 Created response
    static func created(body: String = "", headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: .created, headers: headers, body: body)
    }
    
    /// Create a 204 No Content response
    static func noContent(headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: .noContent, headers: headers)
    }
    
    /// Create a 400 Bad Request response
    static func badRequest(body: String = "Bad Request", headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: .badRequest, headers: headers, body: body)
    }
    
    /// Create a 401 Unauthorized response
    static func unauthorized(
        body: String = "Unauthorized",
        headers: [String: String] = [:],
    ) -> HTTPResponse {
        var h = headers
        h["WWW-Authenticate"] = "Bearer realm=\"server\""
        return HTTPResponse(status: .unauthorized, headers: h, body: body)
    }

    static func unauthorized(
        body: String = "Unauthorized",
        headers: [String: String] = [:],
        bearerRealm: String = "server"
    ) -> HTTPResponse {
        var h = headers
        h["WWW-Authenticate"] = "Bearer realm=\(bearerRealm.escape())"
        return HTTPResponse(status: .unauthorized, headers: h, body: body)
    }

    static func unauthorized(
        body: String = "Unauthorized",
        headers: [String: String] = [:],
        bearerError: String = "invalid_authentication"
    ) -> HTTPResponse {
        var h = headers
        h["WWW-Authenticate"] = "Bearer error=\(bearerError.escape())"
        return HTTPResponse(status: .unauthorized, headers: h, body: body)
    }

    static func tooManyRequests(
        body: String = "Too Many Requests",
        headers: [String: String] = [:]
    ) -> HTTPResponse {
        HTTPResponse(status: .tooManyRequests, headers: headers, body: body)
    }
    
    /// Create a 403 Forbidden response
    static func forbidden(body: String = "Forbidden", headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: .forbidden, headers: headers, body: body)
    }
    
    /// Create a 404 Not Found response
    static func notFound(body: String = "Not Found", headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: .notFound, headers: headers, body: body)
    }
    
    /// Create a 500 Internal Server Error response
    static func internalServerError(body: String = "Internal Server Error", headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: .internalServerError, headers: headers, body: body)
    }

    static func methodNotAllowed(body: String = "Method Not Allowed", headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: .methodNotAllowed, headers: headers, body: body)
    }
}
