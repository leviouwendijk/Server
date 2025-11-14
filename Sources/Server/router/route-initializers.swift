import Foundation

internal func joinPath(_ components: [String]) -> String {
    components.isEmpty ? "/" : "/" + components.joined(separator: "/")
}

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

// PUT Overloads (Variadic)

public func put(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .put, path: joinPath(components), handler: handler)
}

// DELETE Overloads (Variadic)

public func delete(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .delete, path: joinPath(components), handler: handler)
}

// PATCH Overloads (Variadic)

public func patch(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .patch, path: joinPath(components), handler: handler)
}

// HEAD Overloads (Variadic)

public func head(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .head, path: joinPath(components), handler: handler)
}

// Route DSL Container
public func routes(@RouteBuilder _ builder: () -> [Route]) -> [Route] {
    builder()
}
