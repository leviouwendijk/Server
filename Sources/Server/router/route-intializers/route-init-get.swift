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
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: route_default_root,
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func get(
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: route_default_root,
    ) { _ , _ in 
        await body() 
    }
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
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: joinPath(components),
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func get(
    _ components: String...,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: joinPath(components),
    ) { _ , _ in 
        await body() 
    }
}
