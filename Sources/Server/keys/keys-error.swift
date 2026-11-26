import Foundation

/// Why a service's keys could not be found or loaded; the description names
/// the folder or file, so a failed start says what is missing.
public enum KeysError: Error, LocalizedError, CustomStringConvertible, Sendable, Equatable {
    case unset(symbol: String)
    case directoryNotFound(String)
    case invalidName(String)
    case missingFile(String)
    case unreadable(path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .unset(let symbol):
            return "\(symbol) is not set."
        case .directoryNotFound(let directory):
            return "Keys directory '\(directory)' not found above the executable or working directory (within the home folder)."
        case .invalidName(let name):
            return "'\(name)' is not a plain name inside the keys directory."
        case .missingFile(let path):
            return "Key file missing: \(path)."
        case .unreadable(let path, let reason):
            return "Key file unreadable: \(path) (\(reason))."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unset(let symbol):
            return "Set \(symbol) in the env file, relative to the checkout (e.g. env/keys)."
        case .directoryNotFound:
            return "Check that the folder exists in the checkout, or give an absolute path."
        case .invalidName:
            return "Use a single file or folder name without '/'."
        case .missingFile:
            return "Put the key in <keys directory>/<service>/ under that name."
        case .unreadable:
            return "Check that the file is a PEM key of the expected kind."
        }
    }

    public var description: String {
        [errorDescription, recoverySuggestion].compactMap { $0 }.joined(separator: " ")
    }
}
