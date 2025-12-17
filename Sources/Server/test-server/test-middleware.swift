import Foundation
import HTTP
import Milieu

/// Global expected API key, loaded once from env.
/// e.g. export LIBTEST_API_KEY="super-secret"
public let libtestExpectedApiKey: String? = try? EnvironmentExtractor.value(.symbol("LIBTEST_API_KEY"))

/// Wraps a route handler with Bearer-token checking.
/// If the Authorization header is missing/invalid, responds 401.
/// If LIBTEST_API_KEY is not set, responds 500.
public func requireBearerAuth(
    _ handler: @Sendable @escaping (HTTPRequest, Router) -> HTTPResponse
) -> @Sendable (HTTPRequest, Router) -> HTTPResponse {
    return { request, router in
        guard let expected = libtestExpectedApiKey, !expected.isEmpty else {
            return HTTPResponse(
                status: .internalServerError,
                body: "Server misconfigured: LIBTEST_API_KEY not set."
            )
        }

        guard let provided = request.bearerToken() else {
            var resp = HTTPResponse(
                status: .unauthorized,
                body: "Missing or invalid Authorization header."
            )
            resp.headers["WWW-Authenticate"] = "Bearer realm=\"libtest\""
            return resp
        }

        guard provided == expected else {
            var resp = HTTPResponse(
                status: .unauthorized,
                body: "Invalid API token."
            )
            resp.headers["WWW-Authenticate"] = "Bearer error=\"invalid_token\""
            return resp
        }

        // Authorized → call the real handler
        return handler(request, router)
    }
}
