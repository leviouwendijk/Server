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
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: route_default_root,
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func patch(
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: route_default_root,
    ) { _ , _ in 
        await body() 
    }
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
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: joinPath(components),
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func patch(
    _ components: String...,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: joinPath(components),
    ) { _ , _ in 
        await body() 
    }
}
