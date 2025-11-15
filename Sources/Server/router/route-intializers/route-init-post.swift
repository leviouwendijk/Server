import Foundation

// POST Overloads (Variadic)
public func post(
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .post, path: "/", handler: handler)
}

public func post(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .post, path: joinPath(components), handler: handler)
}

// Parameterless overloads
public func post(
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(method: .post, path: "/") { _, _ in await handler() }
}

public func post(
    _ components: String...,
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(method: .post, path: joinPath(components)) { _, _ in await handler() }
}
