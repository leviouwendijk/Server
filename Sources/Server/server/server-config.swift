import Foundation

public enum LogLevel: String, Sendable {
    case debug, info, warn, error
}

public struct ServerConfig: Sendable {
    public let port: UInt16
    public let host: String
    public let logLevel: LogLevel
    public let maxConnections: Int?
    
    public init(
        port: UInt16 = 9090,
        host: String = "127.0.0.1",
        logLevel: LogLevel = .info,
        maxConnections: Int? = nil
    ) {
        self.port = port
        self.host = host
        self.logLevel = logLevel
        self.maxConnections = maxConnections
    }
}
