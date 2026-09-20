import HTTP
import Path
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverQueryRegressionFlow = TestFlow(
        "server.query.regression",
        title: "Server QUERY authoring, discovery, media validation, clients, and CORS remain coherent",
        tags: [
            "cors",
            "http",
            "query",
            "regression",
            "router",
            "server",
        ]
    ) {
        Step("QUERY validates media and advertises discovery metadata") {
            let formats = try queryRegressionFormats()
            let router = queryRegressionRouter(
                formats: formats
            )

            let accepted = await router.route(
                HTTPRequest(
                    method: .query,
                    path: "/search",
                    headers: [
                        "Content-Type": "application/sql; charset=UTF-8",
                    ],
                    body: "SELECT 1"
                )
            )

            try Expect.equal(
                accepted.status,
                .ok,
                "query.accepted.status"
            )

            try Expect.equal(
                accepted.headers.acceptQuery,
                formats,
                "query.accepted.accept-query"
            )

            let unsupported = await router.route(
                HTTPRequest(
                    method: .query,
                    path: "/search",
                    headers: [
                        "Content-Type": "text/plain",
                    ],
                    body: "SELECT 1"
                )
            )

            try Expect.equal(
                unsupported.status,
                .unsupportedMediaType,
                "query.unsupported.status"
            )

            try Expect.equal(
                unsupported.headers.acceptQuery,
                formats,
                "query.unsupported.accept-query"
            )

            let missingType = await router.route(
                HTTPRequest(
                    method: .query,
                    path: "/search",
                    body: "{}"
                )
            )

            try Expect.equal(
                missingType.status,
                .badRequest,
                "query.missing-content-type.status"
            )

            let options = await router.route(
                HTTPRequest(
                    method: .options,
                    path: "/search"
                )
            )

            try Expect.contains(
                options.header(
                    "Allow"
                ) ?? "",
                "QUERY",
                "query.options.allow"
            )

            try Expect.equal(
                options.headers.acceptQuery,
                formats,
                "query.options.accept-query"
            )

            let get = await router.route(
                HTTPRequest(
                    method: .get,
                    path: "/search"
                )
            )

            try Expect.equal(
                get.headers.acceptQuery,
                formats,
                "query.get.accept-query"
            )

            let methodNotAllowed = await router.route(
                HTTPRequest(
                    method: .post,
                    path: "/search"
                )
            )

            try Expect.equal(
                methodNotAllowed.status,
                .methodNotAllowed,
                "query.405.status"
            )

            try Expect.equal(
                methodNotAllowed.headers.acceptQuery,
                formats,
                "query.405.accept-query"
            )
        }

        Step("grouped and StandardPath QUERY authoring preserve capability metadata") {
            let formats = try queryRegressionFormats()

            let router = Router {
                group(
                    "api"
                ) {
                    query(
                        "search"
                    ) {
                        .ok(
                            body: "group-query"
                        )
                    }
                    .acceptQuery(
                        formats
                    )
                }
            }

            let grouped = await router.route(
                HTTPRequest(
                    method: .query,
                    path: "/api/search",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: "{}"
                )
            )

            try Expect.equal(
                grouped.status,
                .ok,
                "query.group.status"
            )

            try Expect.equal(
                grouped.headers.acceptQuery,
                formats,
                "query.group.accept-query"
            )

            let path = StandardPath(
                rawPath: "/standard-query"
            )

            let route = query(
                path
            ) {
                .ok(
                    body: "standard-query"
                )
            }

            try Expect.equal(
                route.method,
                .query,
                "query.standard-path.method"
            )

            try Expect.equal(
                route.path.raw,
                "/standard-query",
                "query.standard-path.path"
            )
        }

        Step("TestClient QUERY convenience sends Content-Type through HTTPClient") {
            let server = try await SecurityTestServer.start(
                routes: [
                    query(
                        "client-query"
                    ) { request in
                        .ok(
                            body: "query-client-ok",
                            headers: [
                                "X-Observed-Content-Type":
                                    request.headers.contentType
                                    ?? "missing-content-type",
                            ]
                        )
                    }
                ]
            )

            do {
                let client = TestClient.withDefaults(
                    host: "127.0.0.1",
                    port: server.port,
                    timeout: 2,
                    debug: false
                )

                let response = try await client.query(
                    "/client-query",
                    body: "{}",
                    contentType: "application/json"
                )

                try Expect.equal(
                    response.status,
                    .ok,
                    "query.client.status"
                )

                try Expect.equal(
                    response.header(
                        "X-Observed-Content-Type"
                    ),
                    "application/json",
                    "query.client.content-type"
                )

                try Expect.equal(
                    response.body,
                    "query-client-ok",
                    "query.client.response-body"
                )

                await server.stop()
            } catch {
                await server.stop()
                throw error
            }
        }

        Step("CORS permits QUERY when explicitly configured") {
            let formats = try queryRegressionFormats()

            let cors = CORSMiddleware(
                allowedOrigin: .only(
                    "https://app.example"
                ),
                allowedMethods: [
                    .query,
                    .options,
                ],
                allowedHeaders: [
                    "Content-Type",
                ]
            )

            let router = Router {
                query(
                    "cors-query"
                ) {
                    .ok(
                        body: "cors-query"
                    )
                }
                .acceptQuery(
                    formats
                )
                .use(
                    cors
                )
                .allow(
                    .options
                )
            }

            let response = await router.route(
                HTTPRequest(
                    method: .options,
                    path: "/cors-query",
                    headers: [
                        "Origin": "https://app.example",
                        "Access-Control-Request-Method": "QUERY",
                        "Access-Control-Request-Headers": "Content-Type",
                    ]
                )
            )

            try Expect.equal(
                response.status,
                .noContent,
                "query.cors.status"
            )

            try Expect.contains(
                response.header(
                    "Access-Control-Allow-Methods"
                ) ?? "",
                "QUERY",
                "query.cors.allow-method"
            )

            try Expect.equal(
                response.headers.acceptQuery,
                formats,
                "query.cors.accept-query"
            )
        }
    }
}

private func queryRegressionFormats() throws -> HTTPAcceptQuery {
    guard let formats = HTTPAcceptQuery(
        rawValue:
            "application/json, application/sql;charset=\"UTF-8\""
    ) else {
        throw ServerQueryRegressionError.invalidFormats
    }

    return formats
}

private func queryRegressionRouter(
    formats: HTTPAcceptQuery
) -> Router {
    Router {
        get(
            "search"
        ) {
            .ok(
                body: "get-search"
            )
        }

        query(
            "search"
        ) {
            .ok(
                body: "query-ok"
            )
        }
        .acceptQuery(
            formats
        )
    }
}

private enum ServerQueryRegressionError: Error {
    case invalidFormats
}
