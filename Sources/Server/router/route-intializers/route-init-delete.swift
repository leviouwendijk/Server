import Foundation

// DELETE Overloads (Variadic)
public func delete(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .delete, path: joinPath(components), handler: handler)
}

// Parameterless overloads
public func delete(
    _ components: String...,
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(method: .delete, path: joinPath(components)) { _, _ in await handler() }
}

// Request-only overloads
public func delete(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(method: .delete, path: joinPath(components)) { request, _ in await handler(request) }
}
