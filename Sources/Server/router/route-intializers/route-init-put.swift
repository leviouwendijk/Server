import Foundation

// PUT Overloads (Variadic)
public func put(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .put, path: joinPath(components), handler: handler)
}

// Parameterless overloads
public func put(
    _ components: String...,
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(method: .put, path: joinPath(components)) { _, _ in await handler() }
}

// Request-only overloads
public func put(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(method: .put, path: joinPath(components)) { request, _ in await handler(request) }
}
