import Foundation
import HTTP

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
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: route_default_root,
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func put(
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: route_default_root,
    ) { _ , _ in 
        await body() 
    }
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
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: joinPath(components),
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func put(
    _ components: String...,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: joinPath(components),
    ) { _ , _ in 
        await body() 
    }
}
