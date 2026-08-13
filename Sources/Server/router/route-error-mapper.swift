import HTTP

public enum RouteErrorPhase: String, Sendable, Equatable {
    case request // parsing
    case handler
    case response // rendering/construction
}

public struct RouteErrorMapper: Sendable {
    public typealias Resolver = @Sendable (
        any Error,
        RouteErrorPhase
    ) -> HTTPResponse?

    private let resolver: Resolver

    public static let none = RouteErrorMapper()

    public init(
        _ mappings: RouteErrorMapper...
    ) {
        self.init(
            mappings
        )
    }

    public init(
        _ mappings: [RouteErrorMapper]
    ) {
        resolver = { error, phase in
            for mapping in mappings {
                if let response = mapping.response(
                    for: error,
                    phase: phase
                ) {
                    return response
                }
            }

            return nil
        }
    }

    private init(
        resolver: @escaping Resolver
    ) {
        self.resolver = resolver
    }

    public func response(
        for error: any Error,
        phase: RouteErrorPhase
    ) -> HTTPResponse? {
        resolver(
            error,
            phase
        )
    }

    public static func handling<Failure: Error>(
        _ type: Failure.Type,
        phase: RouteErrorPhase? = .handler,
        _ response: @Sendable @escaping (
            Failure
        ) -> HTTPResponse
    ) -> RouteErrorMapper {
        RouteErrorMapper(
            resolver: { error, currentPhase in
                if let phase,
                   phase != currentPhase
                {
                    return nil
                }

                guard let error = error as? Failure else {
                    return nil
                }

                return response(
                    error
                )
            }
        )
    }
}
