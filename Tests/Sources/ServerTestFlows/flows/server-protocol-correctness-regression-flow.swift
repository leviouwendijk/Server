import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverProtocolCorrectnessRegressionFlow = TestFlow(
        "server.protocol-correctness.regression",
        title: "Server routing discovery and protocol error responses remain HTTP-correct",
        tags: [
            "server",
            "router",
            "http",
            "query",
            "status",
            "regression",
        ]
    ) {
        Step("405 advertises all currently supported methods") {
            let router = protocolCorrectnessRouter()

            let response = await router.route(
                HTTPRequest(
                    method: .delete,
                    path: "/items"
                )
            )

            try Expect.equal(
                response.status,
                .methodNotAllowed,
                "protocol-correctness.405.status"
            )

            try Expect.equal(
                response.header(
                    "Allow"
                ),
                "GET, HEAD, OPTIONS, QUERY",
                "protocol-correctness.405.allow"
            )
        }

        Step("OPTIONS discovers resource methods without an explicit OPTIONS route") {
            let router = protocolCorrectnessRouter()

            let response = await router.route(
                HTTPRequest(
                    method: .options,
                    path: "/items"
                )
            )

            try Expect.equal(
                response.status,
                .noContent,
                "protocol-correctness.options.status"
            )

            try Expect.equal(
                response.header(
                    "Allow"
                ),
                "GET, HEAD, OPTIONS, QUERY",
                "protocol-correctness.options.allow"
            )
        }

        Step("server policy filtering is reflected in Allow") {
            let router = Router(
                routes: protocolCorrectnessRoutes(),
                methods: [
                    .get,
                    .head,
                    .options,
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .query,
                    path: "/items",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: "{}"
                )
            )

            try Expect.equal(
                response.status,
                .methodNotAllowed,
                "protocol-correctness.policy.status"
            )

            try Expect.equal(
                response.header(
                    "Allow"
                ),
                "GET, HEAD, OPTIONS",
                "protocol-correctness.policy.allow"
            )
        }

        Step("disabled method on an unknown path remains 404") {
            let router = Router(
                routes: protocolCorrectnessRoutes(),
                methods: [
                    .get,
                    .head,
                    .options,
                ]
            )

            let response = await router.route(
                HTTPRequest(
                    method: .query,
                    path: "/missing",
                    headers: [
                        "Content-Type": "application/json",
                    ],
                    body: "{}"
                )
            )

            try Expect.equal(
                response.status,
                .notFound,
                "protocol-correctness.policy.unknown-path"
            )
        }
    }
}

private func protocolCorrectnessRoutes() -> [Route] {
    [
        get(
            "items"
        ) {
            .ok(
                body: "get"
            )
        }
        .allow(
            .head
        ),
        Route(
            method: .query,
            path: "/items"
        ) { _, _ in
            .ok(
                body: "query"
            )
        },
    ]
}

private func protocolCorrectnessRouter() -> Router {
    Router(
        routes: protocolCorrectnessRoutes()
    )
}
