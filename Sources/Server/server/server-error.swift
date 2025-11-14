import Foundation

public enum ServerError: Error, LocalizedError {
    case failedToStartListener(String)
    case connectionFailed(String)
    case invalidConfiguration(String)
    case requestParsingFailed
    case responseEncodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .failedToStartListener(let msg):
            return "Failed to start listener: \(msg)"
        case .connectionFailed(let msg):
            return "Connection failed: \(msg)"
        case .invalidConfiguration(let msg):
            return "Invalid configuration: \(msg)"
        case .requestParsingFailed:
            return "Failed to parse HTTP request"
        case .responseEncodingFailed:
            return "Failed to encode HTTP response"
        }
    }
}
