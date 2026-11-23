import Foundation
import HTTP
import Variables
import Milieu

public struct BearerMiddleware: Middleware {
    public let name = "bearer-auth"
    private let expectedKey: String
    private let realmName: String

    /// An empty key leaves the server misconfigured: every request gets 500.
    public init(rawKey: String, realmName: String = "api") {
        self.expectedKey = rawKey
        self.realmName = realmName
    }

    /// Reads the key from the environment; a missing or empty variable throws at startup.
    public init(symbol: String, realmName: String = "api") throws {
        let key = try EnvironmentExtractor.value(.symbol(symbol))

        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MiddlewareError.emptyKey(symbol)
        }

        self.init(rawKey: key, realmName: realmName)
    }

    /// Tries to auto-synthesize from the 'APP_NAME' environment variable
    /// Appends the provided suffix, and by default uppercases it
    /// Example:
    /// - APP_NAME="Stat" (taken from 'config: ServerConfig', which is String?)
    /// - suffix: .api_key
    /// Returns: "STAT_API_KEY"
    /// Then runs the initializer for environment symbol
    public init(config: ServerConfig, realmName: String = "api", suffix: SynthesizedSymbol = .api_key) throws {
        let symbol = try config.synthesize(suffix)
        try self.init(symbol: symbol, realmName: realmName)
    }

    internal enum AuthorizationStatus: Sendable, Codable {
        case authorized
        case misconfigured
        case missing
        case invalid

        internal var body: String {
            switch self {
            case .authorized:
                return ""
            case .misconfigured:
                return "Internal Server Error"
            case .missing:
                return "Missing or invalid Authorization header."
            case .invalid:
                return "Invalid API token"
            }
        }

        internal var bearerError: String {
            switch self {
            case .authorized:
                return ""
            case .misconfigured:
                return ""
            case .missing:
                return ""
            case .invalid:
                return "invalid_token"
            }
        }
    }

    internal static func authenticate(
        expected: String,
        provided: String?,
        bearerRealm: String = "api"
    ) -> (AuthorizationStatus, HTTPResponse) {
        guard !expected.isEmpty else {
            let status = AuthorizationStatus.misconfigured

            return (
                status,
                .internalServerError(
                    body: status.body
                )
            )
        }

        guard let provided else {
            let status = AuthorizationStatus.missing

            return (
                status,
                .unauthorized(
                    body: status.body,
                    bearerRealm: bearerRealm
                )
            )
        }

        guard ServerConstantTime.equals(
            provided,
            expected
        ) else {
            let status = AuthorizationStatus.invalid

            return (
                status,
                .unauthorized(
                    body: status.body,
                    bearerError: status.bearerError
                )
            )
        }

        return (
            .authorized,
            .ok()
        )
    }

    public func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    ) async -> HTTPResponse {
        let (status, response) = Self.authenticate(
            expected: expectedKey,
            provided: request.bearerToken(),
            bearerRealm: realmName
        )
        
        if status != .authorized {
            return response
        }

        return await next(request, router)
    }
}
