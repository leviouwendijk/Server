import Foundation
import HTTP

// ----------------------------------
// "/" defaults
// ----------------------------------

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

// request
public func post(
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: route_default_root,
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func post(
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: route_default_root,
    ) { _ , _ in 
        await body() 
    }
}

// ----------------------------------
// joined variadic path components
// ----------------------------------

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
    _ components: String...,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: joinPath(components),
    ) { req, _ in 
        await request(req) 
    }
}

// parameterless
public func post(
    _ components: String...,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: joinPath(components),
    ) { _ , _ in 
        await body() 
    }
}
