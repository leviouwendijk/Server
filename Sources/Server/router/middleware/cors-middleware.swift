import Foundation
import HTTP

public struct CORSMiddleware: Middleware {
    public let name = "cors"
    private let cors: CORS

    public init(config: CORSConfig) {
        self.cors = CORS(config: config)
    }

    public init(
        allowedOrigin: CORSConfig.AllowedOrigin,
        allowCredentials: Bool = false,
        allowedMethods: [HTTPMethod] = [.get, .post, .options],
        allowedHeaders: [String] = ["Content-Type", "Authorization"],
        exposedHeaders: [String] = [],
        maxAgeSeconds: Int? = 600
    ) {
        let cfg = CORSConfig(
            allowedOrigin: allowedOrigin,
            allowCredentials: allowCredentials,
            allowedMethods: allowedMethods,
            allowedHeaders: allowedHeaders,
            exposedHeaders: exposedHeaders,
            maxAgeSeconds: maxAgeSeconds
        )
        self.cors = CORS(config: cfg)
    }

    public func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    ) async -> HTTPResponse {
        // Handle preflight OPTIONS early
        if let preflight = cors.preflightResponse(for: request) {
            return preflight
        }

        // For normal requests, run the rest of the chain
        let response = await next(request, router)

        // Add CORS headers to the response if applicable
        return cors.apply(to: response, for: request)
    }
}
