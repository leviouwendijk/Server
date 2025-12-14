import Foundation
import plate

public enum BearerAuthorityError: Error, LocalizedError {
    case misconfigured

    public var errorDescription: String? {
        switch self {
        case .misconfigured:
            return "Bearere authority misconfigured"
        }
    }
}

public struct BearerAuthority: Sendable {
    public let authorized: Set<String>
    public let invalidated: Set<String>

    /// Accepts raw tokens (less safe, unless you're dealing in short-lived tokens)
    public init(
        authorized_tokens: Set<String>,
        invalidated_tokens: Set<String> = []
    ) throws {
        guard !authorized_tokens.isEmpty else {
            throw BearerAuthorityError.misconfigured
        }

        self.authorized = authorized_tokens
        self.invalidated = invalidated_tokens
    }

    /// Accepts symbols used for environment extraction
    public init(
        authorized: [String],
        invalidated: [String] = [],
    ) throws {
        var authorized_tokens: [String] = []
        for symbol in authorized {
            let token = try EnvironmentExtractor.value(.symbol(symbol))
            authorized_tokens.append(token)
        }
        let auth_set = Set(authorized_tokens)

        var invalidated_tokens: [String] = []
        for symbol in invalidated {
            let token = try EnvironmentExtractor.value(.symbol(symbol))
            invalidated_tokens.append(token)
        }
        let invalid_set = Set(invalidated_tokens)

        try self.init(
            authorized_tokens: auth_set,
            invalidated_tokens: invalid_set
        )
    }

    /// Accepts 'ServerConfig' for pre-registering app-based '<APP>_API_KEY' symbol
    /// Possiblity for manual additions in symbols
    public init(
        config: ServerConfig,
        suffix: SynthesizedSymbol = .api_key,

        authorized: [String] = [],
        invalidated: [String] = [],
    ) throws {
        let symbol = try config.autoSynthesizeTokenSymbol(suffix: suffix)

        var auth_symbols: [String] = []
        auth_symbols.append(symbol)
        auth_symbols.append(contentsOf: authorized)

        try self.init(
            authorized: auth_symbols,
            invalidated: invalidated,
        )
    }

    // more actor like:
    // requires lets to become vars

    // public mutating func authorize(token: String) -> Void {
    //     authorized.formUnion([token])
    // }

    // public mutating func invalidate(token: String) -> Void {
    //     invalidated.formUnion([token])
    // }

    // public mutating func authorize(symbol: String) throws -> Void {
    //     let value = try EnvironmentExtractor.value(.symbol(symbol))
    //     authorize(token: value)
    // }

    // public mutating func invalidate(symbol: String) throws -> Void {
    //     let value = try EnvironmentExtractor.value(.symbol(symbol))
    //     invalidate(token: value)
    // }

    // public mutating func authorize(
    //     config: ServerConfig,
    //     suffix: SynthesizedSymbol = .api_key
    // ) throws -> Void {
    //     let symbol = try config.autoSynthesizeTokenSymbol(suffix: suffix)
    //     try authorize(symbol: symbol)
    // }
    // // skipping invalidate mirroring for now, assuming app apikey is either updated or authorized
}
