import Foundation
import Variables
import Milieu
import Loggers
import Cryptography
import HTTP

public struct ServerConfig: Sendable {
    public let name: String?
    public let port: UInt16
    public let host: String
    public let logLevel: LogLevel
    public let maxConnections: Int?
    public let limits: ServerLimits
    public let timeouts: ServerTimeouts
    public let security: ServerSecurity
    public let json: ServerJSONPolicy

    public init(
        name: String? = nil,
        port: UInt16 = 9090,
        host: String = "127.0.0.1",
        logLevel: LogLevel = .info,
        maxConnections: Int? = nil,
        limits: ServerLimits = .default,
        timeouts: ServerTimeouts = .default,
        security: ServerSecurity = .default,
        json: ServerJSONPolicy = .default
    ) {
        self.name = name
        self.port = port
        self.host = host
        self.logLevel = logLevel
        self.maxConnections = maxConnections
        self.limits = limits
        self.timeouts = timeouts
        self.security = security
        self.json = json
    }

    public static func externallyManagedProcess(
        name: String? = nil,
        logLevel: LogLevel? = nil,
        maxConnections: Int? = nil,
        limits: ServerLimits = .default,
        timeouts: ServerTimeouts = .default,
        security: ServerSecurity = .default,
        json: ServerJSONPolicy = .default
    ) -> Self {
        Self(
            name: name ?? env("APP_NAME"),
            port: envPort(default: 9091),
            host: env("HOST") ?? "127.0.0.1",
            logLevel: envLogLevel(
                logLevel,
                default: .info
            ),
            // maxConnections: maxConnections,
            maxConnections: envMaxConnections(
                maxConnections
            ),
            limits: limits,
            timeouts: timeouts,
            security: security,
            json: json
        )
    }

    public var requestPolicies: HTTPRequestPolicies {
        HTTPRequestPolicies(
            headers: limits.headers,
            content: limits.content,
            target: security.target
        )
    }

    public var requestContentLengthPolicy: HTTPContentLengthPolicy {
        limits.content
    }

    public var requestHeaderPolicy: HTTPHeaderPolicy {
        limits.headers
    }

    public var requestTargetPolicy: HTTPRequestTargetPolicy {
        security.target
    }

    public var allowedMethods: Set<HTTPMethod> {
        security.methods
    }

    public func synthesize(
        _ suffix: SynthesizedSymbol = .api_key
    ) throws -> String {
        let options = SyntheticSymbolOptions(
            suffix: suffix
        )

        return try SynthesizedSymbol.synthesize(
            name: resolveName(),
            using: options
        )
    }

    @available(
        *,
        deprecated,
        renamed: "synthesize(_:)"
    )
    public func autoSynthesizeTokenSymbol(
        suffix: SynthesizedSymbol = .api_key
    ) throws -> String {
        try synthesize(
            suffix
        )
    }

    public func resolveName() throws -> String {
        guard let name else {
            throw ConfigError.failedToResolveName
        }

        return name
    }

    public func keys() throws -> CryptographicKeyPair {
        let name = try resolveName()

        return try CryptographicKeyOperation.keys(
            prefix: name
        )
    }

    private static func env(
        _ symbol: String
    ) -> String? {
        try? EnvironmentExtractor.value(
            .symbol(symbol)
        )
    }

    private static func envMaxConnections(
        _ provided: Int?
    ) -> Int? {
        if let provided {
            return provided
        }

        guard let value = env(
            "MAX_CONNECTIONS"
        ),
        let maximum = Int(
            value
        ),
        maximum > 0
        else {
            return nil
        }

        return maximum
    }

    private static func envPort(
        default fallback: UInt16
    ) -> UInt16 {
        guard let value = env("PORT"),
              let port = UInt16(value)
        else {
            return fallback
        }

        return port
    }

    private static func envLogLevel(
        _ provided: LogLevel?,
        default fallback: LogLevel
    ) -> LogLevel {
        if let provided {
            return provided
        }

        guard let value = env("LOG_LEVEL") else {
            return fallback
        }

        return LogLevel(
            rawValue: value.lowercased()
        ) ?? fallback
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
