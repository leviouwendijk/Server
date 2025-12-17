import Foundation
import HTTP

// ----------------------------------
// "/" defaults
// ----------------------------------

// request + router
public func delete(
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .delete,
        path: route_default_root,
        handler: handler
    )
}

// request
public func delete(
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .delete,
        path: route_default_root,
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func delete(
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .delete,
        path: route_default_root,
    ) { _ , _ in 
        await body() 
    }
}

// ----------------------------------
// joined variadic path components
// ----------------------------------

// request + router
public func delete(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .delete,
        path: joinPath(components),
        handler: handler
    )
}

// request
public func delete(
    _ components: String...,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .delete,
        path: joinPath(components),
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func delete(
    _ components: String...,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .delete,
        path: joinPath(components),
    ) { _ , _ in 
        await body() 
    }
}
