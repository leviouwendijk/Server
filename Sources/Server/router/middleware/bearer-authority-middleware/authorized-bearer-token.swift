import Foundation

public enum BearerTokenError: Error, LocalizedError {
    case unauthorized
    case expired

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized token"
        case .expired:
            return "Expired token"
        }
    }
}

// parse ( compiler safety ), don't validate:
public struct AuthorizedBearerToken: Sendable {
    public let token: String
    
    public init(
        token: String,
        authority: BearerAuthority
    ) throws {
        guard 
            !authority.invalidated.contains(token)
        else {
            throw BearerTokenError.expired
        }

        guard 
            authority.authorized.contains(token)
        else {
            throw BearerTokenError.unauthorized
        }

        self.token = token
    }
}
