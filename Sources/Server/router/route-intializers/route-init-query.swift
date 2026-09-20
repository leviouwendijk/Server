import Foundation
import HTTP

// ----------------------------------
// "/" defaults
// ----------------------------------

public func query(
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .query,
        path: route_default_root,
        handler: handler
    )
}

public func query(
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .query,
        path: route_default_root
    ) { requestValue, _ in
        await request(
            requestValue
        )
    }
}

public func query(
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .query,
        path: route_default_root
    ) { _, _ in
        await body()
    }
}

// ----------------------------------
// joined variadic path components
// ----------------------------------

public func query(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .query,
        path: joinPath(
            components
        ),
        handler: handler
    )
}

public func query(
    _ components: String...,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .query,
        path: joinPath(
            components
        )
    ) { requestValue, _ in
        await request(
            requestValue
        )
    }
}

public func query(
    _ components: String...,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .query,
        path: joinPath(
            components
        )
    ) { _, _ in
        await body()
    }
}
