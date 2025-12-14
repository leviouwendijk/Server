import Foundation
import plate

public struct BearerAuthorityMiddleware: Middleware {
    public let name = "bearer-authority-auth"
    private let realmName: String

    private let bearerAuthority: BearerAuthority

    public init(
        bearerAuthority: BearerAuthority,
        realmName: String = "api"
    ) {
        self.bearerAuthority = bearerAuthority
        self.realmName = realmName
    }

    public init(
        bearerAuthorityProvider: @escaping @Sendable () throws -> BearerAuthority,
        realmName: String = "api"
    ) throws {
        self.bearerAuthority = try bearerAuthorityProvider()
        self.realmName = realmName
    }

    internal enum AuthorizationStatus: Sendable, Codable {
        case authorized
        case missing
        case invalid
        case expired

        internal var body: String {
            switch self {
            case .authorized:
                return ""
            case .missing:
                return "Missing or invalid Authorization header."
            case .invalid:
                return "Invalid API token"
            case .expired:
                return "Expired token"
            }
        }

        internal var bearerError: String {
            switch self {
            case .invalid, .expired:
                return "invalid_token"
            case .authorized, .missing:
                return ""
            }
        }
    }

    internal static func authenticate(
        authority: BearerAuthority,
        provided: String?,
        bearerRealm: String
    ) -> (AuthorizationStatus, HTTPResponse) {
        guard let provided else {
            let status: AuthorizationStatus = .missing
            return (
                status,
                .unauthorized(
                    body: status.body,
                    bearerRealm: bearerRealm
                )
            )
        }

        do {
            _ = try AuthorizedBearerToken(
                token: provided,
                authority: authority
            )
            return (.authorized, .ok())
        } catch let err as BearerTokenError {
            let status: AuthorizationStatus = (err == .expired) ? .expired : .invalid
            return (
                status,
                .unauthorized(
                    body: status.body,
                    bearerError: status.bearerError
                )
            )
        } catch {
            let status: AuthorizationStatus = .invalid
            return (
                status,
                .unauthorized(
                    body: status.body,
                    bearerError: status.bearerError
                )
            )
        }
    }

    public func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    ) async -> HTTPResponse {
        let (status, response) = Self.authenticate(
            authority: bearerAuthority,
            provided: request.bearerToken(),
            bearerRealm: realmName
        )

        if status != .authorized {
            return response
        }

        return await next(request, router)
    }
}
