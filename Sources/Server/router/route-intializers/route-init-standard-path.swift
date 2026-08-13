import HTTP
import Path

// EXAMPLE API:
// let auth = StandardPath(
//     "auth",
//     "create",
// )

// Router {
//     get(
//         auth.child.get("login")
//     ) {
//         .ok()
//     }

//     post(
//         auth.child.get("token")
//     ) { request in
//         .ok()
//     }

//     delete(
//         auth.child.get("sessions")
//     ) { request, router in
//         .ok()
//     }
// }

// note: sometimes the omission of args gets into compiler errors
// for its ambiguity

public extension Route {
    init(
        method: HTTPMethod,
        path: StandardPath,
        handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
    ) {
        self.init(
            method: method,
            path: path.render(
                as: .root,
                filetype: true
            ),
            handler: handler
        )
    }
}

public func get(
    _ path: StandardPath,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: path,
        handler: handler
    )
}

public func get(
    _ path: StandardPath,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: path
    ) { req, _ in
        await request(req)
    }
}

public func get(
    _ path: StandardPath,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .get,
        path: path
    ) { _, _ in
        await body()
    }
}

public func head(
    _ path: StandardPath,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .head,
        path: path,
        handler: handler
    )
}

public func head(
    _ path: StandardPath,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .head,
        path: path
    ) { req, _ in
        await request(req)
    }
}

public func head(
    _ path: StandardPath,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .head,
        path: path
    ) { _, _ in
        await body()
    }
}

public func options(
    _ path: StandardPath,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .options,
        path: path,
        handler: handler
    )
}

public func options(
    _ path: StandardPath,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .options,
        path: path
    ) { req, _ in
        await request(req)
    }
}

public func options(
    _ path: StandardPath,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .options,
        path: path
    ) { _, _ in
        await body()
    }
}

public func patch(
    _ path: StandardPath,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: path,
        handler: handler
    )
}

public func patch(
    _ path: StandardPath,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: path
    ) { req, _ in
        await request(req)
    }
}

public func patch(
    _ path: StandardPath,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .patch,
        path: path
    ) { _, _ in
        await body()
    }
}

public func post(
    _ path: StandardPath,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: path,
        handler: handler
    )
}

public func post(
    _ path: StandardPath,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: path
    ) { req, _ in
        await request(req)
    }
}

public func post(
    _ path: StandardPath,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .post,
        path: path
    ) { _, _ in
        await body()
    }
}

public func put(
    _ path: StandardPath,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: path,
        handler: handler
    )
}

public func put(
    _ path: StandardPath,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: path
    ) { req, _ in
        await request(req)
    }
}

public func put(
    _ path: StandardPath,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .put,
        path: path
    ) { _, _ in
        await body()
    }
}

public func delete(
    _ path: StandardPath,
    handler: @Sendable @escaping (HTTPRequest, Router) async -> HTTPResponse
) -> Route {
    Route(
        method: .delete,
        path: path,
        handler: handler
    )
}

public func delete(
    _ path: StandardPath,
    request: @Sendable @escaping (HTTPRequest) async -> HTTPResponse
) -> Route {
    Route(
        method: .delete,
        path: path
    ) { req, _ in
        await request(req)
    }
}

public func delete(
    _ path: StandardPath,
    body: @Sendable @escaping () async -> HTTPResponse
) -> Route {
    Route(
        method: .delete,
        path: path
    ) { _, _ in
        await body()
    }
}
