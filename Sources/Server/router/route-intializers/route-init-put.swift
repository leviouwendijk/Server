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
