import Foundation

// ----------------------------------
// "/" defaults
// ----------------------------------

// request + router
public func put(
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: route_default_root,
        handler: handler
    )
}

// request
public func put(
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: route_default_root,
        handler: { request, _ in 
            await handler(request) 
        }
    )
}

// parameterless
public func put(
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
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
public func put(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: joinPath(components),
        handler: handler
    )
}

// request
public func put(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: joinPath(components),
        handler: { request, _ in 
            await handler(request) 
        }
    )
}

// parameterless
public func put(
    _ components: String...,
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: joinPath(components),
        handler: { request, _ in 
            await handler() 
        }
    )
}
