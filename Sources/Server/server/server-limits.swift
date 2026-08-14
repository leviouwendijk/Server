import HTTP

public struct ServerLimits: Sendable, Hashable, Equatable {
    public let content: HTTPContentPolicy
    public let headers: HTTPHeaderPolicy

    public init(
        content: HTTPContentPolicy = .default,
        headers: HTTPHeaderPolicy = HTTPHeaderPolicy.request.default
    ) {
        self.content = content
        self.headers = headers
    }

    public static let `default` = Self()

    public static let formAPI = Self(
        content: .formAPI
    )

    public static let tinyJSONAPI = Self(
        content: .tinyJSONAPI
    )

    public static let smallJSONAPI = Self(
        content: .smallJSONAPI
    )

    public static let standardJSONAPI = Self(
        content: .standardJSONAPI
    )

    public static let largeJSONAPI = Self(
        content: .largeJSONAPI
    )

    public static let uploadAPI = Self(
        content: .uploadAPI
    )

    public static let internalBulkAPI = Self(
        content: .internalBulkAPI
    )
}
