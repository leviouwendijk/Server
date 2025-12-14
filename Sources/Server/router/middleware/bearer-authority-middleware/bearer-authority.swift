import Foundation
import plate

public enum BearerAuthorityError: Error, LocalizedError, Sendable {
    case misconfigured
    case sanitizationFailed(kind: Kind, emptyOrWhitespace: Int, modifiedByTrimming: Int)

    public enum Kind: String, Sendable {
        case authorized
        case invalidated
    }

    public var errorDescription: String? {
        switch self {
        case .misconfigured:
            return "Bearer authority misconfigured"
        case let .sanitizationFailed(kind, empty, modified):
            return "Bearer authority \(kind.rawValue) tokens failed sanitization (empty/whitespace: \(empty), trimming-changed: \(modified))"
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
        let authorized = try Self.sanitize(authorized_tokens, kind: .authorized)
        let invalidated = try Self.sanitize(invalidated_tokens, kind: .invalidated)

        guard !authorized.isEmpty else {
            throw BearerAuthorityError.misconfigured
        }

        self.authorized = authorized
        self.invalidated = invalidated
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

    private static func sanitize(
        _ tokens: Set<String>,
        kind: BearerAuthorityError.Kind
    ) throws (BearerAuthorityError) -> Set<String> {
        var emptyOrWhitespace = 0
        var modifiedByTrimming = 0
        var out: Set<String> = []
        out.reserveCapacity(tokens.count)

        for token in tokens {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                emptyOrWhitespace += 1
                continue
            }

            if trimmed != token {
                modifiedByTrimming += 1
            }

            out.insert(trimmed)
        }

        if emptyOrWhitespace > 0 || modifiedByTrimming > 0 {
            throw .sanitizationFailed(
                kind: kind,
                emptyOrWhitespace: emptyOrWhitespace,
                modifiedByTrimming: modifiedByTrimming
            )
        }

        return out
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
