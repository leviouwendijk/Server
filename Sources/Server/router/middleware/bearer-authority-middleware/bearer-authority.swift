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

    private init(
        authorized: Set<String>,
        invalidated: Set<String>
    ) throws {
        guard !authorized.isEmpty else {
            throw BearerAuthorityError.misconfigured
        }

        self.authorized = authorized
        self.invalidated = invalidated
    }

    public init(
        authorizedSymbols: [String],
        invalidatedSymbols: [String],

        authorized: Set<String>,
        invalidated: Set<String>
    ) throws {
        var authorized_tokens: [String] = []
        for symbol in authorizedSymbols {
            let token = try EnvironmentExtractor.value(.symbol(symbol))
            authorized_tokens.append(token)
        }
        let auth_set = Set(authorized_tokens)

        var invalidated_tokens: [String] = []
        for symbol in invalidatedSymbols {
            let token = try EnvironmentExtractor.value(.symbol(symbol))
            invalidated_tokens.append(token)
        }
        let invalid_set = Set(invalidated_tokens)

        try self.init(
            authorized: auth_set.union(authorized),
            invalidated: invalid_set.union(invalidated)
        )
    }

    public init(
        config: ServerConfig,
        suffix: SynthesizedSymbol = .api_key,

        authorizedSymbols: [String] = [],
        invalidatedSymbols: [String] = [],

        authorized: Set<String> = [],
        invalidated: Set<String> = []
    ) throws {
        let symbol = try config.autoSynthesizeTokenSymbol(suffix: suffix)

        var auth_symbols: [String] = []
        auth_symbols.append(symbol)
        auth_symbols.append(contentsOf: authorizedSymbols)

        try self.init(
            authorizedSymbols: auth_symbols,
            invalidatedSymbols: invalidatedSymbols,
            authorized: authorized,
            invalidated: invalidated
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
