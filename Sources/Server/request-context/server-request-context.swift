public protocol ServerRequestContextKey:
    Sendable
{
    associatedtype Value: Sendable
}

public struct ServerRequestContext:
    Sendable
{
    private var values: [
        ObjectIdentifier: any Sendable
    ]

    public init() {
        self.values = [:]
    }

    public func value<Key: ServerRequestContextKey>(
        for key: Key.Type
    ) -> Key.Value? {
        values[
            ObjectIdentifier(key)
        ] as? Key.Value
    }

    public func setting<Key: ServerRequestContextKey>(
        _ value: Key.Value,
        for key: Key.Type
    ) -> Self {
        var copy = self

        copy.values[
            ObjectIdentifier(key)
        ] = value

        return copy
    }

    public func removing<Key: ServerRequestContextKey>(
        _ key: Key.Type
    ) -> Self {
        var copy = self

        copy.values.removeValue(
            forKey: ObjectIdentifier(key)
        )

        return copy
    }
}

public enum ServerRequestScope {
    @TaskLocal
    public static var current = ServerRequestContext()

    public static func value<Key: ServerRequestContextKey>(
        for key: Key.Type
    ) -> Key.Value? {
        current.value(
            for: key
        )
    }

    public static func withValue<
        Key: ServerRequestContextKey,
        Result
    >(
        _ value: Key.Value,
        for key: Key.Type,
        operation: () async throws -> Result
    ) async rethrows -> Result {
        let context = current.setting(
            value,
            for: key
        )

        return try await $current.withValue(
            context,
            operation: operation
        )
    }
}
