import Foundation
import plate

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
        logLevel: LogLevel? = nil,
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
        
        if let log = logLevel { // first passed arg
            self.logLevel = log
        } else if let levelStr = try? EnvironmentExtractor.value(.symbol("LOG_LEVEL")) { // then env
            self.logLevel = LogLevel(rawValue: levelStr.lowercased()) ?? .info
        } else {
            self.logLevel = .info // then defaulft
        }

        self.name = try? EnvironmentExtractor.value(.symbol("APP_NAME"))
        self.maxConnections = maxConnections
    }

    public static func externallyManagedProcess(
        logLevel: LogLevel? = nil,
        maxConnections: Int? = nil,
    ) -> Self {
        return self.init(logLevel: logLevel, maxConnections: maxConnections)
    }

    public func autoSynthesizeTokenSymbol(suffix: SynthesizedSymbol = .api_key) throws -> String {
        let options = SyntheticSymbolOptions(suffix: suffix)
        return try SynthesizedSymbol.synthesize(name: name, using: options)
    }

    public func resolveName() throws -> String {
        guard let name else {
            throw ConfigError.failedToResolveName
        }
        return name
    }

    public func keys() throws -> CryptographicKeyPair {
        let n = try resolveName()
        // let pub = try CryptographicKeyOperation.loadKey(name: n, .public)
        // let priv = try CryptographicKeyOperation.loadKey(name: n, .private)
        // return .init(
        //     publicKey: pub,
        //     privateKey: priv
        // )
        return try CryptographicKeyOperation.keys(prefix: n)
    }
}

// try keys() comes to replace a binary-side state.swift implemenation like:
//
// let replacer = EnvironmentReplacer(replacements: [.variable(key: "$HOME", replacement: .home)])
//
// internal func keys() throws -> CryptographicKeyPair {
//     let name = try config.resolveName()
//
//     let pubPath = try EnvironmentExtractor.value(
//         name: name,
//         suffix: .public_key_path,
//         replacer: replacer
//     )
//     let privPath = try EnvironmentExtractor.value(
//         name: name,
//         suffix: .private_key_path,
//         replacer: replacer
//     )
//
//     let publicKey  = try CryptographicKeyOperation.loadPublicKey(at: pubPath)
//     let privateKey = try CryptographicKeyOperation.loadPrivateKey(at: privPath)
//
//     return CryptographicKeyPair(publicKey: publicKey, privateKey: privateKey)
// }
