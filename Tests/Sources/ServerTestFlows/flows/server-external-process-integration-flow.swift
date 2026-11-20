import HTTP
import Server
import TestFlows
import TestFlowsProcesses

extension ServerSecurityFlows {
    static let serverExternalProcessIntegrationFlow = TestFlow(
        "server.external-process.integration",
        title: "External Server process preserves HTTP semantics over real TCP",
        tags: [
            "server",
            "http",
            "network",
            "process",
            "integration",
        ]
    ) {
        Step(
            "GET and synthetic HEAD cross the external process boundary"
        ) {
            try await usingFixture(
                serverProcessFixture()
            ) { server in
                let client = externalHTTPClient(
                    server
                )

                try Expect.greaterThan(
                    server.processIdentifier,
                    Int64(0),
                    "external server exposes a process identifier"
                )

                try Expect.greaterThan(
                    server.ready.port,
                    UInt16(0),
                    "external server reports an OS-assigned port"
                )

                let getResponse = try await client.get(
                    "/health"
                )

                try Expect.equal(
                    getResponse.status.code,
                    200,
                    "external GET status"
                )

                try Expect.equal(
                    getResponse.body,
                    "ok",
                    "external GET body"
                )

                let headResponse = try await client.send(
                    method: .head,
                    path: "/health"
                )

                try Expect.equal(
                    headResponse.status.code,
                    200,
                    "external HEAD status"
                )

                try Expect.equal(
                    headResponse.body,
                    "",
                    "external HEAD strips response body"
                )
            }
        }

        Step(
            "POST preserves request body and custom headers"
        ) {
            try await usingFixture(
                serverProcessFixture()
            ) { server in
                let client = externalHTTPClient(
                    server
                )

                let response = try await client.post(
                    "/echo",
                    body: "external-post-body",
                    headers: [
                        "X-Test": "wire-header",
                    ]
                )

                try Expect.equal(
                    response.status.code,
                    200,
                    "external POST status"
                )

                try Expect.equal(
                    response.body,
                    "external-post-body",
                    "external POST body round trip"
                )

                try Expect.equal(
                    response.header(
                        "X-Observed-Test"
                    ),
                    "wire-header",
                    "external POST custom header round trip"
                )
            }
        }

        Step(
            "QUERY transports Content-Type and enforces advertised media"
        ) {
            try await usingFixture(
                serverProcessFixture()
            ) { server in
                let client = externalHTTPClient(
                    server
                )

                let accepted = try await client.query(
                    "/search",
                    body: #"{"term":"dogs"}"#,
                    contentType: "application/json"
                )

                try Expect.equal(
                    accepted.status.code,
                    200,
                    "external QUERY accepted status"
                )

                try Expect.equal(
                    accepted.body,
                    #"query:{"term":"dogs"}"#,
                    "external QUERY request body"
                )

                try Expect.equal(
                    accepted.header(
                        "X-Observed-Content-Type"
                    ),
                    "application/json",
                    "external QUERY Content-Type"
                )

                try Expect.contains(
                    accepted.header(
                        "Accept-Query"
                    ) ?? "",
                    "application/json",
                    "external QUERY advertises Accept-Query"
                )

                let rejected = try await client.query(
                    "/search",
                    body: "dogs",
                    contentType: "text/plain"
                )

                try Expect.equal(
                    rejected.status.code,
                    415,
                    "external QUERY unsupported media status"
                )

                try Expect.contains(
                    rejected.header(
                        "Accept-Query"
                    ) ?? "",
                    "application/json",
                    "external QUERY rejection preserves discovery metadata"
                )
            }
        }

        Step(
            "404 405 and OPTIONS discovery survive real wire transport"
        ) {
            try await usingFixture(
                serverProcessFixture()
            ) { server in
                let client = externalHTTPClient(
                    server
                )

                let missing = try await client.get(
                    "/missing"
                )

                try Expect.equal(
                    missing.status.code,
                    404,
                    "external unknown path status"
                )

                let methodNotAllowed = try await client.delete(
                    "/resource"
                )

                try Expect.equal(
                    methodNotAllowed.status.code,
                    405,
                    "external method mismatch status"
                )

                try Expect.equal(
                    methodNotAllowed.header(
                        "Allow"
                    ),
                    "GET, HEAD, OPTIONS, QUERY",
                    "external method discovery Allow header"
                )

                try Expect.contains(
                    methodNotAllowed.header(
                        "Accept-Query"
                    ) ?? "",
                    "application/json",
                    "external 405 advertises QUERY media"
                )

                let options = try await client.send(
                    method: .options,
                    path: "/resource"
                )

                try Expect.equal(
                    options.status.code,
                    204,
                    "external OPTIONS status"
                )

                try Expect.equal(
                    options.header(
                        "Allow"
                    ),
                    "GET, HEAD, OPTIONS, QUERY",
                    "external OPTIONS Allow header"
                )

                try Expect.contains(
                    options.header(
                        "Accept-Query"
                    ) ?? "",
                    "application/json",
                    "external OPTIONS advertises QUERY media"
                )
            }
        }

        Step(
            "independent concurrent clients remain isolated"
        ) {
            try await usingFixture(
                serverProcessFixture()
            ) { server in
                let config = externalHTTPClientConfig(
                    server
                )

                let firstClient = HTTPClient(
                    config: config
                )
                let secondClient = HTTPClient(
                    config: config
                )

                async let first = firstClient.get(
                    "/one"
                )
                async let second = secondClient.get(
                    "/two"
                )

                let (
                    firstResponse,
                    secondResponse
                ) = try await (
                    first,
                    second
                )

                try Expect.equal(
                    firstResponse.status.code,
                    200,
                    "first concurrent client status"
                )

                try Expect.equal(
                    secondResponse.status.code,
                    200,
                    "second concurrent client status"
                )

                try Expect.equal(
                    firstResponse.body,
                    "one",
                    "first concurrent client body"
                )

                try Expect.equal(
                    secondResponse.body,
                    "two",
                    "second concurrent client body"
                )
            }
        }
    }
}

private func externalHTTPClient(
    _ server: ProcessFixtureHandle<ServerProcessFixtureReady>
) -> HTTPClient {
    HTTPClient(
        config: externalHTTPClientConfig(
            server
        )
    )
}

private func externalHTTPClientConfig(
    _ server: ProcessFixtureHandle<ServerProcessFixtureReady>
) -> HTTPClientConfig {
    HTTPClientConfig(
        host: server.ready.host,
        port: server.ready.port,
        timeout: 2,
        debug: false
    )
}
