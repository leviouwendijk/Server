import Foundation

// GET Overloads (Variadic)
public func get(
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .get, path: "/", handler: handler)
}

public func get(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .get, path: joinPath(components), handler: handler)
}

// Parameterless overloads
public func get(
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(method: .get, path: "/") { _, _ in await handler() }
}

public func get(
    _ components: String...,
    handler: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(method: .get, path: joinPath(components)) { _, _ in await handler() }
}
