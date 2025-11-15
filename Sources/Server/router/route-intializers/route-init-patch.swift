import Foundation

// PATCH Overloads (Variadic)
public func patch(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .patch, path: joinPath(components), handler: handler)
}

// Parameterless overloads
public func patch(
    _ components: String...,
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(method: .patch, path: joinPath(components)) { _, _ in await handler() }
}

// Request-only overloads
public func patch(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(method: .patch, path: joinPath(components)) { request, _ in await handler(request) }
}
