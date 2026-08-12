import Foundation

public enum ConfigError: Error, LocalizedError {
    case failedToResolveName

    public var errorDescription: String? {
        switch self {
        case .failedToResolveName:
            return "Failed to resolve name"
        }
    }

    public var failureReason: String? {
        switch self {
        case .failedToResolveName:
            return "The name parameter is empty"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .failedToResolveName:
            return "Ensure the name parameter is set or passed through the environment (ex.: 'APP_NAME')"
        }
    }
}
