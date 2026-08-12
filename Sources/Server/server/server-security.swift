import HTTP

public struct ServerSecurity: Sendable, Hashable, Equatable {
    public let target: HTTPRequestTargetPolicy
    public let methods: Set<HTTPMethod>

    public init(
        target: HTTPRequestTargetPolicy = .default,
        methods: Set<HTTPMethod> = HTTPMethod.defaultServerAllowed
    ) {
        self.target = target
        self.methods = methods
    }

    public static let `default` = Self()

    public static let permissive = Self(
        target: .permissive,
        methods: HTTPMethod.allServerMethods
    )
}
