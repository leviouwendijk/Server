import Foundation
import Parsers

public struct CORSConfig: Sendable {
    public enum AllowedOrigin: Sendable {
        case any                      // "*", but adjusted when allowCredentials = true
        case only(String)             // exact single origin
        case whitelist(Set<String>)   // small fixed set
        case matcher(Prebuilt.CORSOriginMatcher)   // new

        public func allowed(for request: HTTPRequest, allowCredentials: Bool) -> String? {
            // If there is no Origin header, this is not a CORS request.
            guard let origin = request.header("Origin") else {
                return nil
            }

            switch self {
            case .any:
                if allowCredentials {
                    // With credentials you cannot use "*", so echo the request Origin.
                    return origin
                } else {
                    return "*"
                }

            case .only(let allowed):
                return origin == allowed ? allowed : nil

            case .whitelist(let set):
                return set.contains(origin) ? origin : nil

            case .matcher(let matcher):
                return matcher.allows(origin) ? origin : nil
            }
        }
    }

    public let allowedOrigin: AllowedOrigin
    public let allowCredentials: Bool
    public let allowedMethods: [HTTPMethod]
    public let allowedHeaders: [String]
    public let exposedHeaders: [String]
    public let maxAgeSeconds: Int?

    public init(
        allowedOrigin: AllowedOrigin,
        allowCredentials: Bool = false,
        allowedMethods: [HTTPMethod] = [.get, .post, .options],
        allowedHeaders: [String] = ["Content-Type", "Authorization"],
        exposedHeaders: [String] = [],
        maxAgeSeconds: Int? = 600
    ) {
        self.allowedOrigin = allowedOrigin
        self.allowCredentials = allowCredentials
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.exposedHeaders = exposedHeaders
        self.maxAgeSeconds = maxAgeSeconds
    }
}

public struct CORS: Sendable {
    public let config: CORSConfig

    public init(config: CORSConfig) {
        self.config = config
    }

    // /// Handle a potential CORS preflight. Returns a response if we handled it,
    // /// or nil if this is not a CORS preflight request.
    // public func preflightResponse(for request: HTTPRequest) -> HTTPResponse? {
    //     guard request.method == .options,
    //           request.header("Origin") != nil,
    //           request.header("Access-Control-Request-Method") != nil
    //     else {
    //         return nil
    //     }

    //     guard let allowOrigin = config.allowedOrigin.allowed(for: request, allowCredentials: config.allowCredentials) else {
    //         // Origin not allowed – SHOULD be 403/other, but we can just not CORS it
    //         return HTTPResponse.noContent()
    //     }

    //     var resp = HTTPResponse.noContent()

    //     // Required CORS headers
    //     resp.headers["Access-Control-Allow-Origin"] = allowOrigin
    //     resp.headers["Vary"] = "Origin"

    //     let methods = config.allowedMethods.map(\.rawValue).joined(separator: ", ")
    //     resp.headers["Access-Control-Allow-Methods"] = methods

    //     if !config.allowedHeaders.isEmpty {
    //         resp.headers["Access-Control-Allow-Headers"] = config.allowedHeaders.joined(separator: ", ")
    //     }

    //     if let maxAge = config.maxAgeSeconds {
    //         resp.headers["Access-Control-Max-Age"] = String(maxAge)
    //     }

    //     if config.allowCredentials {
    //         resp.headers["Access-Control-Allow-Credentials"] = "true"
    //     }

    //     return resp
    // }

    /// Handle OPTIONS for CORS-controlled routes.
    ///
    /// Important:
    /// Once an OPTIONS request reaches CORSMiddleware, it must be terminal.
    /// It must not fall through into route handlers, auth, rate-limiters, or upstream calls.
    public func preflightResponse(
        for request: HTTPRequest
    ) -> HTTPResponse? {
        guard request.method == .options else {
            return nil
        }

        guard let allowOrigin = config.allowedOrigin.allowed(
            for: request,
            allowCredentials: config.allowCredentials
        ) else {
            return HTTPResponse.noContent()
        }

        if let requestedMethod = request.header("Access-Control-Request-Method")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
           !requestedMethod.isEmpty {
            let allowed = Set(
                config.allowedMethods.map {
                    $0.rawValue.uppercased()
                }
            )

            guard allowed.contains(requestedMethod) else {
                return HTTPResponse.noContent()
            }
        }

        var response = HTTPResponse.noContent()

        response.headers["Access-Control-Allow-Origin"] = allowOrigin
        response.headers["Vary"] = "Origin, Access-Control-Request-Method, Access-Control-Request-Headers"

        response.headers["Access-Control-Allow-Methods"] = config.allowedMethods
            .map(\.rawValue)
            .joined(separator: ", ")

        if !config.allowedHeaders.isEmpty {
            response.headers["Access-Control-Allow-Headers"] = config.allowedHeaders
                .joined(separator: ", ")
        }

        if let maxAge = config.maxAgeSeconds {
            response.headers["Access-Control-Max-Age"] = String(maxAge)
        }

        if config.allowCredentials {
            response.headers["Access-Control-Allow-Credentials"] = "true"
        }

        return response
    }


    /// Apply CORS headers to a normal response (non-preflight).
    public func apply(to response: HTTPResponse, for request: HTTPRequest) -> HTTPResponse {
        guard let allowOrigin = config.allowedOrigin.allowed(for: request, allowCredentials: config.allowCredentials) else {
            return response
        }

        var resp = response
        resp.headers["Access-Control-Allow-Origin"] = allowOrigin
        resp.headers["Vary"] = "Origin"

        if config.allowCredentials {
            resp.headers["Access-Control-Allow-Credentials"] = "true"
        }

        if !config.exposedHeaders.isEmpty {
            resp.headers["Access-Control-Expose-Headers"] = config.exposedHeaders.joined(separator: ", ")
        }

        return resp
    }
}

extension HTTPResponse {
    /// Apply an existing CORS policy to this response.
    public mutating func applyCORS(_ cors: CORS, for request: HTTPRequest) {
        self = cors.apply(to: self, for: request)
    }

    /// Non-mutating convenience.
    public func withCORS(_ cors: CORS, for request: HTTPRequest) -> HTTPResponse {
        cors.apply(to: self, for: request)
    }

    /// Build a CORS policy ad-hoc and apply it.
    public mutating func applyCORS(
        allowedOrigin: CORSConfig.AllowedOrigin,
        allowCredentials: Bool = false,
        allowedMethods: [HTTPMethod] = [.get, .post, .options],
        allowedHeaders: [String] = ["Content-Type", "Authorization"],
        exposedHeaders: [String] = [],
        maxAgeSeconds: Int? = 600,
        for request: HTTPRequest
    ) {
        let config = CORSConfig(
            allowedOrigin: allowedOrigin,
            allowCredentials: allowCredentials,
            allowedMethods: allowedMethods,
            allowedHeaders: allowedHeaders,
            exposedHeaders: exposedHeaders,
            maxAgeSeconds: maxAgeSeconds
        )
        let cors = CORS(config: config)
        self = cors.apply(to: self, for: request)
    }

    /// Non-mutating sibling for the ad-hoc version.
    public func withCORS(
        allowedOrigin: CORSConfig.AllowedOrigin,
        allowCredentials: Bool = false,
        allowedMethods: [HTTPMethod] = [.get, .post, .options],
        allowedHeaders: [String] = ["Content-Type", "Authorization"],
        exposedHeaders: [String] = [],
        maxAgeSeconds: Int? = 600,
        for request: HTTPRequest
    ) -> HTTPResponse {
        var copy = self
        copy.applyCORS(
            allowedOrigin: allowedOrigin,
            allowCredentials: allowCredentials,
            allowedMethods: allowedMethods,
            allowedHeaders: allowedHeaders,
            exposedHeaders: exposedHeaders,
            maxAgeSeconds: maxAgeSeconds,
            for: request
        )
        return copy
    }
}
