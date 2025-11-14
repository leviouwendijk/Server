import Foundation
import plate

public struct BearerMiddleware: Middleware {
    public let name = "bearer-auth"
    private let expectedKey: String?
    private let realmName: String
    
    public init(rawKey: String, realmName: String = "api") {
        self.expectedKey = rawKey
        self.realmName = realmName
    }
    
    public init(envSymbol: String, realmName: String = "api") throws {
        self.expectedKey = try EnvironmentExtractor.value(.symbol(envSymbol))
        self.realmName = realmName
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
                return "Server misconfigured: key has not been set."
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
        expected: String?,
        provided: String?,
        bearerRealm: String = "api"
    ) -> (AuthorizationStatus, HTTPResponse) {
        let status: AuthorizationStatus
        let response: HTTPResponse

        if expected == nil {
            status = .misconfigured
            response = .unauthorized(
                body: status.body,
                bearerRealm: bearerRealm
            )
        } else if provided == nil {
            status = .missing
            response = .unauthorized(
                body: status.body,
                bearerRealm: bearerRealm
            )
        } else if !(provided == expected) {
            status = .invalid
            response = .unauthorized(
                body: status.body,
                bearerError: status.bearerError
            )
        } else {
            status = .authorized
            response = .ok()
        }

        return (status, response)
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
