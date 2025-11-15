import Foundation

// ----------------------------------
// "/" defaults
// ----------------------------------

// request + router
public func get(
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: route_default_root,
        handler: handler
    )
}

// request
public func get(
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: route_default_root,
        handler: { request, _ in 
            await handler(request) 
        }
    )
}

// parameterless
public func get(
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
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
public func get(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: joinPath(components),
        handler: handler
    )
}

// request
public func get(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: joinPath(components),
        handler: { request, _ in 
            await handler(request) 
        }
    )
}

// parameterless
public func get(
    _ components: String...,
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: joinPath(components),
        handler: { request, _ in 
            await handler() 
        }
    )
}
