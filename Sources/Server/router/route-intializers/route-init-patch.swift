import Foundation

// ----------------------------------
// "/" defaults
// ----------------------------------

// request + router
public func patch(
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: route_default_root,
        handler: handler
    )
}

// request
public func patch(
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: route_default_root,
        handler: { request, _ in 
            await handler(request) 
        }
    )
}

// parameterless
public func patch(
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: route_default_root,
        handler: { request, _ in 
            await handler() 
        }
    )
}

// ----------------------------------
// joined variadic path components
// ----------------------------------

// request + router
public func patch(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: joinPath(components),
        handler: handler
    )
}

// request
public func patch(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: joinPath(components),
        handler: { request, _ in 
            await handler(request) 
        }
    )
}

// parameterless
public func patch(
    _ components: String...,
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: joinPath(components),
        handler: { request, _ in 
            await handler() 
        }
    )
}
