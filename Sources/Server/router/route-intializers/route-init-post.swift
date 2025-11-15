import Foundation

// request + router
public func post(
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: route_default_root,
        handler: handler
    )
}

// request + router
public func post(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: joinPath(components),
        handler: handler
    )
}


// request
public func post(
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: route_default_root,
        handler: { request, _ in 
            await handler(request) 
        }
    )
}

// request
public func post(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: joinPath(components),
        handler: { request, _ in 
            await handler(request) 
        }
    )
}

// parameterless
public func post(
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: route_default_root,
        handler: { request, _ in 
            await handler() 
        }
    )
}

// parameterless
public func post(
    _ components: String...,
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: joinPath(components),
        handler: { request, _ in 
            await handler() 
        }
    )
}
