import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverRequestContextFlow = TestFlow(
        "server.request-context",
        title: "Server request-scoped values remain typed and isolated",
        tags: [
            "server",
            "request",
            "context",
            "task-local",
            "regression",
        ]
    ) {
        Step("value is absent outside a request scope") {
            try Expect.equal(
                ServerRequestScope.value(
                    for: RequestContextStringKey.self
                ),
                nil,
                "request-context.absent"
            )
        }

        Step("value is available inside its request scope") {
            try await ServerRequestScope.withValue(
                "authenticated",
                for: RequestContextStringKey.self
            ) {
                try Expect.equal(
                    ServerRequestScope.value(
                        for: RequestContextStringKey.self
                    ),
                    "authenticated",
                    "request-context.available"
                )
            }

            try Expect.equal(
                ServerRequestScope.value(
                    for: RequestContextStringKey.self
                ),
                nil,
                "request-context.restored"
            )
        }

        Step("different typed values can coexist") {
            try await ServerRequestScope.withValue(
                "principal:test",
                for: RequestContextStringKey.self
            ) {
                try await ServerRequestScope.withValue(
                    42,
                    for: RequestContextIntegerKey.self
                ) {
                    try Expect.equal(
                        ServerRequestScope.value(
                            for: RequestContextStringKey.self
                        ),
                        "principal:test",
                        "request-context.typed.string"
                    )

                    try Expect.equal(
                        ServerRequestScope.value(
                            for: RequestContextIntegerKey.self
                        ),
                        42,
                        "request-context.typed.integer"
                    )
                }
            }
        }

        Step("nested scope restores its outer value") {
            try await ServerRequestScope.withValue(
                "outer",
                for: RequestContextStringKey.self
            ) {
                try Expect.equal(
                    ServerRequestScope.value(
                        for: RequestContextStringKey.self
                    ),
                    "outer",
                    "request-context.nested.outer-before"
                )

                try await ServerRequestScope.withValue(
                    "inner",
                    for: RequestContextStringKey.self
                ) {
                    try Expect.equal(
                        ServerRequestScope.value(
                            for: RequestContextStringKey.self
                        ),
                        "inner",
                        "request-context.nested.inner"
                    )
                }

                try Expect.equal(
                    ServerRequestScope.value(
                        for: RequestContextStringKey.self
                    ),
                    "outer",
                    "request-context.nested.outer-after"
                )
            }
        }

        Step("concurrent request scopes remain isolated") {
            async let first: String? = ServerRequestScope.withValue(
                "first",
                for: RequestContextStringKey.self
            ) {
                try? await Task.sleep(
                    for: .milliseconds(10)
                )

                return ServerRequestScope.value(
                    for: RequestContextStringKey.self
                )
            }

            async let second: String? = ServerRequestScope.withValue(
                "second",
                for: RequestContextStringKey.self
            ) {
                return ServerRequestScope.value(
                    for: RequestContextStringKey.self
                )
            }

            let results = await (
                first,
                second
            )

            try Expect.equal(
                results.0,
                "first",
                "request-context.concurrent.first"
            )

            try Expect.equal(
                results.1,
                "second",
                "request-context.concurrent.second"
            )
        }
    }
}

private enum RequestContextStringKey:
    ServerRequestContextKey
{
    typealias Value = String
}

private enum RequestContextIntegerKey:
    ServerRequestContextKey
{
    typealias Value = Int
}
