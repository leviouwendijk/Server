import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverRouterBaselineRegressionFlow = TestFlow(
        "server.router-baseline.regression",
        title: "Router preserves exact dispatch, fallback, synthetic methods, and middleware composition",
        tags: [
            "server",
            "router",
            "middleware",
            "routing",
            "regression",
        ]
    ) {
        Step("exact route dispatch preserves route metadata") {
            let router = Router(
                routes: [
                    Route(
                        method: .get,
                        path: "/items"
                    ) { _, _ in
                        .text(
                            "exact"
                        )
                    },
                ]
            )

            let result = await router.observed(
                HTTPRequest(
                    method: .get,
                    path: "/items"
                )
            )

            try Expect.equal(
                result.response.status.code,
                200,
                "router-baseline.exact.status"
            )

            try Expect.equal(
                result.response.body,
                "exact",
                "router-baseline.exact.body"
            )

            try Expect.equal(
                result.pattern,
                "/items" as String?,
                "router-baseline.exact.pattern"
            )

            try Expect.equal(
                result.method,
                HTTPMethod.get as HTTPMethod?,
                "router-baseline.exact.method"
            )

            try Expect.false(
                result.synthetic,
                "router-baseline.exact.synthetic"
            )
        }

        Step("router distinguishes method mismatch from missing path") {
            let router = Router(
                routes: [
                    Route(
                        method: .get,
                        path: "/items"
                    ) { _, _ in
                        .text(
                            "ok"
                        )
                    },
                ]
            )

            let methodMismatch = await router.observed(
                HTTPRequest(
                    method: .post,
                    path: "/items"
                )
            )

            let missing = await router.observed(
                HTTPRequest(
                    method: .get,
                    path: "/missing"
                )
            )

            try Expect.equal(
                methodMismatch.response.status.code,
                405,
                "router-baseline.fallback.method-not-allowed"
            )

            try Expect.equal(
                missing.response.status.code,
                404,
                "router-baseline.fallback.not-found"
            )
        }

        Step("synthetic HEAD uses GET route and strips response body") {
            let route = Route(
                method: .get,
                path: "/items"
            ) { _, _ in
                .text(
                    "should-not-be-returned"
                )
            }
            .allow(
                .head
            )

            let router = Router(
                routes: [
                    route,
                ]
            )

            let result = await router.observed(
                HTTPRequest(
                    method: .head,
                    path: "/items"
                )
            )

            try Expect.equal(
                result.response.status.code,
                200,
                "router-baseline.head.status"
            )

            try Expect.equal(
                result.response.body,
                "",
                "router-baseline.head.body"
            )

            try Expect.true(
                result.synthetic,
                "router-baseline.head.synthetic"
            )

            try Expect.equal(
                result.method,
                HTTPMethod.get as HTTPMethod?,
                "router-baseline.head.route-method"
            )
        }

        Step("synthetic OPTIONS uses explicitly allowed route") {
            let route = Route(
                method: .post,
                path: "/items"
            ) { _, _ in
                HTTPResponse(
                    status: .noContent
                )
            }
            .allow(
                .options
            )

            let router = Router(
                routes: [
                    route,
                ]
            )

            let result = await router.observed(
                HTTPRequest(
                    method: .options,
                    path: "/items"
                )
            )

            try Expect.equal(
                result.response.status.code,
                204,
                "router-baseline.options.status"
            )

            try Expect.true(
                result.synthetic,
                "router-baseline.options.synthetic"
            )

            try Expect.equal(
                result.method,
                HTTPMethod.post as HTTPMethod?,
                "router-baseline.options.route-method"
            )
        }

        Step("middleware nesting order remains stable") {
            let trace = RouterBaselineTrace()

            let route = Route(
                method: .get,
                path: "/middleware"
            ) { _, _ in
                await trace.record(
                    "handler"
                )

                return .text(
                    "ok"
                )
            }
            .use(
                RouterBaselineMiddleware(
                    name: "first",
                    trace: trace
                )
            )
            .use(
                RouterBaselineMiddleware(
                    name: "second",
                    trace: trace
                )
            )

            let router = Router(
                routes: [
                    route,
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .get,
                    path: "/middleware"
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "router-baseline.middleware.status"
            )

            let events = await trace.snapshot()

            try Expect.equal(
                events,
                [
                    "first.before",
                    "second.before",
                    "handler",
                    "second.after",
                    "first.after",
                ],
                "router-baseline.middleware.order"
            )
        }

        Step("StandardPath route overloads preserve rooted paths across HTTP verbs") {
            let routes: [Route] = [
                get(
                    .init(
                        "standard-path",
                        "get-handler"
                    ),
                    handler: { _, _ in
                        .text(
                            "get-handler"
                        )
                    }
                ),
                get(
                    .init(
                        "standard-path",
                        "get-request"
                    ),
                    request: { _ in
                        .text(
                            "get-request"
                        )
                    }
                ),
                get(
                    .init(
                        "standard-path",
                        "get-body"
                    ),
                    body: {
                        .text(
                            "get-body"
                        )
                    }
                ),
                head(
                    .init(
                        "standard-path",
                        "head"
                    ),
                    body: {
                        .text(
                            "head"
                        )
                    }
                ),
                options(
                    .init(
                        "standard-path",
                        "options"
                    ),
                    body: {
                        .text(
                            "options"
                        )
                    }
                ),
                patch(
                    .init(
                        "standard-path",
                        "patch"
                    ),
                    body: {
                        .text(
                            "patch"
                        )
                    }
                ),
                post(
                    .init(
                        "standard-path",
                        "post"
                    ),
                    body: {
                        .text(
                            "post"
                        )
                    }
                ),
                put(
                    .init(
                        "standard-path",
                        "put"
                    ),
                    body: {
                        .text(
                            "put"
                        )
                    }
                ),
                delete(
                    .init(
                        "standard-path",
                        "delete"
                    ),
                    body: {
                        .text(
                            "delete"
                        )
                    }
                ),
            ]

            try Expect.equal(
                routes.map {
                    $0.method
                },
                [
                    .get,
                    .get,
                    .get,
                    .head,
                    .options,
                    .patch,
                    .post,
                    .put,
                    .delete,
                ],
                "router-standard-path.verbs.methods"
            )

            try Expect.equal(
                routes.map {
                    $0.path.raw
                },
                [
                    "/standard-path/get-handler",
                    "/standard-path/get-request",
                    "/standard-path/get-body",
                    "/standard-path/head",
                    "/standard-path/options",
                    "/standard-path/patch",
                    "/standard-path/post",
                    "/standard-path/put",
                    "/standard-path/delete",
                ],
                "router-standard-path.verbs.paths"
            )
        }

        Step("StandardPath root remains the router root path") {
            let route = get(
                .init(
                    rawPath: "/"
                ),
                body: {
                    .text(
                        "root"
                    )
                }
            )

            try Expect.equal(
                route.path.raw,
                "/",
                "router-standard-path.root.path"
            )
        }

        Step("nested StandardPath groups compose and dispatch rooted paths") {
            let grouped = group(
                .init(
                    "api",
                    "v1"
                )
            ) {
                get(
                    body: {
                        .text(
                            "api-root"
                        )
                    }
                )

                group(
                    .init(
                        "auth"
                    )
                ) {
                    get(
                        .init(
                            "login"
                        ),
                        body: {
                            .text(
                                "login"
                            )
                        }
                    )

                    post(
                        .init(
                            "token"
                        ),
                        request: { request in
                            .text(
                                request.path.raw
                            )
                        }
                    )
                }
            }

            try Expect.equal(
                grouped.routes.map {
                    $0.path.raw
                },
                [
                    "/api/v1",
                    "/api/v1/auth/login",
                    "/api/v1/auth/token",
                ],
                "router-standard-path.groups.paths"
            )

            let router = Router(
                routes: grouped.routes
            )

            let rootResponse = await router.route(
                HTTPRequest(
                    method: .get,
                    path: "/api/v1"
                )
            )

            try Expect.equal(
                rootResponse.status.code,
                200,
                "router-standard-path.groups.root.status"
            )

            try Expect.equal(
                rootResponse.body,
                "api-root",
                "router-standard-path.groups.root.body"
            )

            let loginResponse = await router.route(
                HTTPRequest(
                    method: .get,
                    path: "/api/v1/auth/login"
                )
            )

            try Expect.equal(
                loginResponse.status.code,
                200,
                "router-standard-path.groups.login.status"
            )

            try Expect.equal(
                loginResponse.body,
                "login",
                "router-standard-path.groups.login.body"
            )

            let tokenResponse = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/api/v1/auth/token"
                )
            )

            try Expect.equal(
                tokenResponse.status.code,
                200,
                "router-standard-path.groups.token.status"
            )

            try Expect.equal(
                tokenResponse.body,
                "/api/v1/auth/token",
                "router-standard-path.groups.token.body"
            )
        }

        Step("string and StandardPath groups preserve route metadata") {
            let policy = ServerJSONPolicy(
                decodeTo: .camel,
                encodeAs: .snake
            )

            let stringTrace = RouterBaselineTrace()

            let stringGrouped = group(
                "string"
            ) {
                get(
                    "metadata",
                    body: {
                        .text(
                            "string"
                        )
                    }
                )
                .json(
                    policy
                )
                .allow(
                    .head
                )
                .use(
                    RouterBaselineMiddleware(
                        name: "string-group",
                        trace: stringTrace
                    )
                )
            }

            let standardPathTrace = RouterBaselineTrace()

            let standardPathGrouped = group(
                .init(
                    "standard-path"
                )
            ) {
                get(
                    .init(
                        "metadata"
                    ),
                    body: {
                        .text(
                            "standard-path"
                        )
                    }
                )
                .json(
                    policy
                )
                .allow(
                    .head
                )
                .use(
                    RouterBaselineMiddleware(
                        name: "standard-path-group",
                        trace: standardPathTrace
                    )
                )
            }

            try Expect.equal(
                stringGrouped.routes.first?.path.raw,
                "/string/metadata" as String?,
                "router-group-metadata.string.path"
            )

            try Expect.equal(
                stringGrouped.routes.first?.jsonPolicy,
                policy as ServerJSONPolicy?,
                "router-group-metadata.string.json-policy"
            )

            try Expect.equal(
                stringGrouped.routes.first?.middleware.count,
                1 as Int?,
                "router-group-metadata.string.middleware"
            )

            try Expect.true(
                stringGrouped.routes.first?.syntheticMethods.contains(
                    .head
                ) == true,
                "router-group-metadata.string.synthetic-method"
            )

            try Expect.equal(
                standardPathGrouped.routes.first?.path.raw,
                "/standard-path/metadata" as String?,
                "router-group-metadata.standard-path.path"
            )

            try Expect.equal(
                standardPathGrouped.routes.first?.jsonPolicy,
                policy as ServerJSONPolicy?,
                "router-group-metadata.standard-path.json-policy"
            )

            try Expect.equal(
                standardPathGrouped.routes.first?.middleware.count,
                1 as Int?,
                "router-group-metadata.standard-path.middleware"
            )

            try Expect.true(
                standardPathGrouped.routes.first?.syntheticMethods.contains(
                    .head
                ) == true,
                "router-group-metadata.standard-path.synthetic-method"
            )
        }
    }
}

private actor RouterBaselineTrace {
    private var events: [String] = []

    func record(
        _ event: String
    ) {
        events.append(
            event
        )
    }

    func snapshot() -> [String] {
        events
    }
}

private struct RouterBaselineMiddleware: Middleware {
    let name: String
    let trace: RouterBaselineTrace

    func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (
            HTTPRequest,
            Router
        ) async -> HTTPResponse
    ) async -> HTTPResponse {
        await trace.record(
            "\(name).before"
        )

        let response = await next(
            request,
            router
        )

        await trace.record(
            "\(name).after"
        )

        return response
    }
}
