import Foundation

// ----------------------------------
// "/" defaults
// ----------------------------------

// request + router
public func options(
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .options,
        path: route_default_root,
        handler: handler
    )
}

// request
public func options(
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .options,
        path: route_default_root,
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func options(
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .options,
        path: route_default_root,
    ) { _ , _ in 
        await body() 
    }
}

// ----------------------------------
// joined variadic path components
// ----------------------------------

// request + router
public func options(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .options,
        path: joinPath(components),
        handler: handler
    )
}

// request
public func options(
    _ components: String...,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .options,
        path: joinPath(components),
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func options(
    _ components: String...,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .options,
        path: joinPath(components),
    ) { _ , _ in 
        await body() 
    }
}
