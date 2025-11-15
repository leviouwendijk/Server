import Foundation
import plate

// public enum LogLevel: String, Sendable {
//     case debug, info, warn, error
// }

public struct ServerConfig: Sendable {
    public let name: String?
    public let port: UInt16
    public let host: String
    public let logLevel: LogLevel
    public let maxConnections: Int?
    
    public init(
        name: String? = nil,
        port: UInt16 = 9090,
        host: String = "127.0.0.1",
        logLevel: LogLevel = .info,
        maxConnections: Int? = nil
    ) {
        self.name = name
        self.port = port
        self.host = host
        self.logLevel = logLevel
        self.maxConnections = maxConnections
    }

    public init(
        name: String? = nil,
        maxConnections: Int? = nil
    ) {
        if let portStr = try? EnvironmentExtractor.value(.symbol("PORT")),
           let portValue = UInt16(portStr) {
            self.port = portValue
        } else {
            self.port = 9091  // Default fallback
        }
        
        if let hostValue = try? EnvironmentExtractor.value(.symbol("HOST")) {
            self.host = hostValue
        } else {
            self.host = "127.0.0.1"
        }
        
        if let levelStr = try? EnvironmentExtractor.value(.symbol("LOG_LEVEL")) {
            self.logLevel = LogLevel(rawValue: levelStr.lowercased()) ?? .info
        } else {
            self.logLevel = .info
        }

        self.name = try? EnvironmentExtractor.value(.symbol("APP_NAME"))
        self.maxConnections = maxConnections
    }

    public static func externallyManagedProcess(maxConnections: Int? = nil) -> Self {
        return self.init(maxConnections: maxConnections)
    }

    // public func startNotification() -> String {
    //     return "\(name ?? "Application") server running on \(host):\(port)"
    // }

    public func autoSynthesizeTokenSymbol(suffix: SynthesizedSymbol = .api_key) throws -> String {
        let options = try SyntheticSymbolOptions(name: name, suffix: suffix)
        return SynthesizedSymbol.synthesize(using: options)
    }
}
