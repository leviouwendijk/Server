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

    /// Proxies whose forwarding headers are believed when resolving the client address.
    public let trustedProxies: HTTPTrustedProxies
    public let limits: ServerLimits
    public let timeouts: ServerTimeouts
    public let security: ServerSecurity
    public let json: ServerJSONPolicy

    public init(
        name: String? = nil,
        port: UInt16 = 9090,
        host: String = "127.0.0.1",
        logLevel: LogLevel = .info,
        maxConnections: Int? = Self.defaultMaxConnections,
        trustedProxies: HTTPTrustedProxies = .loopback,
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
        self.trustedProxies = trustedProxies
        self.limits = limits
        self.timeouts = timeouts
        self.security = security
        self.json = json
    }

    /// Concurrent connections accepted before new ones are refused.
    public static let defaultMaxConnections: Int? = 1_024

    /// Reads `APP_NAME`, `PORT`, `HOST`, `LOG_LEVEL`, `MAX_CONNECTIONS` and
    /// `TRUSTED_PROXIES` (comma-separated addresses or CIDR ranges; default loopback).
    public static func externallyManagedProcess(
        name: String? = nil,
        logLevel: LogLevel? = nil,
        maxConnections: Int? = nil,
        trustedProxies: HTTPTrustedProxies? = nil,
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
            maxConnections: envMaxConnections(
                maxConnections
            ),
            trustedProxies: trustedProxies ?? envTrustedProxies(),
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

    public var requestContentPolicy: HTTPContentPolicy {
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

    /// The service's keys from `<KEYS_DIRECTORY>/<name>/`, with file names fixed
    /// by the service. A missing directory or file throws a `KeysError` that
    /// names it.
    public func keys(
        public publicKey: String,
        private privateKey: String,
        directory symbol: String = "KEYS_DIRECTORY"
    ) throws -> CryptographicKeyPair {
        try ServiceKeys(
            .init(
                directory: KeysDirectory(symbol: symbol),
                service: resolveName(),
                publicKey: publicKey,
                privateKey: privateKey
            )
        )
        .pair
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
            return defaultMaxConnections
        }

        return maximum
    }

    /// An unparsable value stops the process: silently trusting fewer proxies would
    /// attribute every request to the proxy, and trusting more would allow spoofing.
    private static func envTrustedProxies() -> HTTPTrustedProxies {
        guard let value = env(
            "TRUSTED_PROXIES"
        ) else {
            return .loopback
        }

        do {
            return try .parsing(
                value
            )
        } catch {
            fatalError(
                "TRUSTED_PROXIES: \(error.localizedDescription)"
            )
        }
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
