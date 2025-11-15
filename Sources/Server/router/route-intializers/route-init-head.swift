import Foundation

// HEAD Overloads (Variadic)
public func head(
    _ components: String...,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(method: .head, path: joinPath(components), handler: handler)
}

// Parameterless overloads
