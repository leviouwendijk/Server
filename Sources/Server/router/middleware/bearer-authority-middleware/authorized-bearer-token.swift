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
        let fingerprint =
            BearerAuthority.fingerprint(
                token
            )

        guard !authority.invalidatedFingerprints.contains(
            fingerprint
        ) else {
            throw BearerTokenError.expired
        }

        guard authority.authorizedFingerprints.contains(
            fingerprint
        ) else {
            throw BearerTokenError.unauthorized
        }

        self.token = token
    }
}
