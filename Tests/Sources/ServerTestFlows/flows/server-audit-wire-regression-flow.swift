import Foundation
import HTTP
@_spi(Testing) import Server
import TestFlows

// Regressions for the 2026-11-23 HTTP/Server audit, exercised on the wire.
// Issues: plans/code/depaix/libraries/issues/

private func auditRoutes() -> [Route] {
    [
        Route(
            method: .get,
            path: "/ok"
        ) { request, _ in
            .ok(
                body: "ok"
            )
        },
        Route(
            method: .head,
            path: "/head"
        ) { _, _ in
            .ok(
                body: "HEADBODY"
            )
        },
        Route(
            method: .get,
            path: "/empty"
        ) { _, _ in
            HTTPResponse(
                status: .noContent
            )
        },
        Route(
            method: .post,
            path: "/len"
        ) { request, _ in
            .ok(
                body: "bytes=\(request.bodyData.count)"
            )
        },
        Route(
            method: .get,
            path: "/ip"
        ) { request, _ in
            .ok(
                body: "ip=\(request.clientIP ?? "nil")"
            )
        },
        Route(
            method: .get,
            path: "/slow"
        ) { _, _ in
            try? await Task.sleep(
                for: .milliseconds(300)
            )

            return .ok(
                body: "slow-done"
            )
        },
    ]
}

private func exchange(
    _ server: SecurityTestServer,
    _ raw: String,
    timeout: TimeInterval = 0.6,
    until predicate: @escaping @Sendable (String) -> Bool = { _ in false }
) async throws -> String {
    let connection = SecurityTestConnection(
        port: server.port
    )

    guard await connection.start() else {
        throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
    }

    guard await connection.send(
        raw
    ) else {
        connection.cancel()
        throw SecurityNetworkHarnessError.sendFailed
    }

    let text = await connection.receive(
        until: predicate,
        timeout: timeout
    ) ?? ""

    connection.cancel()

    return text
}

private func withAuditServer(
    trustedProxies: HTTPTrustedProxies = .loopback,
    _ operation: (SecurityTestServer) async throws -> Void
) async throws {
    let server = try await SecurityTestServer.start(
        trustedProxies: trustedProxies,
        timeouts: ServerTimeouts(
            idle: .seconds(5),
            headers: .seconds(2),
            content: .seconds(2)
        ),
        routes: auditRoutes()
    )

    do {
        try await operation(
            server
        )
        await server.stop()
    } catch {
        await server.stop()
        throw error
    }
}

extension ServerSecurityFlows {
    static let serverAuditWireRegressionFlow = TestFlow(
        "server.audit-wire.regression",
        title: "Audit findings stay fixed on the wire",
        tags: [
            "audit",
            "regression",
            "server",
            "wire",
        ]
    ) {
        Step("whitespace before the colon and obs-fold lines are rejected") {
            try await withAuditServer { server in
                let spaced = try await exchange(
                    server,
                    "POST /len HTTP/1.1\r\nHost: x\r\nContent-Length : 5\r\n\r\nhello"
                )

                try Expect.contains(
                    spaced,
                    "HTTP/1.1 400",
                    "audit.header-name-space.400"
                )

                try Expect.contains(
                    spaced,
                    "Connection: close",
                    "audit.header-name-space.close"
                )

                let folded = try await exchange(
                    server,
                    "POST /len HTTP/1.1\r\nHost: x\r\n Content-Length: 5\r\n\r\nhello"
                )

                try Expect.contains(
                    folded,
                    "HTTP/1.1 400",
                    "audit.obs-fold.400"
                )
            }
        }

        Step("HEAD responses carry no body, so a pipelined request stays in sync") {
            try await withAuditServer { server in
                let text = try await exchange(
                    server,
                    "HEAD /head HTTP/1.1\r\nHost: x\r\n\r\nGET /ok HTTP/1.1\r\nHost: x\r\n\r\n",
                    until: {
                        $0.hasSuffix(
                            "ok"
                        )
                    }
                )

                try Expect.doesNotContain(
                    text,
                    "HEADBODY",
                    "audit.head.no-body"
                )

                try Expect.contains(
                    text,
                    "Content-Length: 8",
                    "audit.head.length"
                )

                try Expect.true(
                    text.hasSuffix(
                        "\r\n\r\nok"
                    ),
                    "audit.head.pipeline-in-sync"
                )
            }
        }

        Step("204 carries no Content-Length") {
            try await withAuditServer { server in
                let text = try await exchange(
                    server,
                    "GET /empty HTTP/1.1\r\nHost: x\r\n\r\n",
                    until: {
                        $0.hasSuffix(
                            "\r\n\r\n"
                        )
                    }
                )

                try Expect.contains(
                    text,
                    "HTTP/1.1 204",
                    "audit.204.status"
                )

                try Expect.doesNotContain(
                    text,
                    "Content-Length",
                    "audit.204.no-length"
                )
            }
        }

        Step("Connection: close is honored and echoed") {
            try await withAuditServer { server in
                let text = try await exchange(
                    server,
                    "GET /ok HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n",
                    until: {
                        $0.hasSuffix(
                            "ok"
                        )
                    }
                )

                try Expect.contains(
                    text,
                    "Connection: close",
                    "audit.connection-close.echoed"
                )

                await securityTestDelay(
                    0.2
                )

                try Expect.equal(
                    await server.engine.retainedConnectionHandlerCount,
                    0,
                    "audit.connection-close.closed"
                )
            }
        }

        Step("HTTP/1.0 is served and closed; missing Host on HTTP/1.1 is 400") {
            try await withAuditServer { server in
                let http10 = try await exchange(
                    server,
                    "GET /ok HTTP/1.0\r\n\r\n",
                    until: {
                        $0.hasSuffix(
                            "ok"
                        )
                    }
                )

                try Expect.contains(
                    http10,
                    "HTTP/1.1 200",
                    "audit.http10.served"
                )

                try Expect.contains(
                    http10,
                    "Connection: close",
                    "audit.http10.close"
                )

                let hostless = try await exchange(
                    server,
                    "GET /ok HTTP/1.1\r\n\r\n"
                )

                try Expect.contains(
                    hostless,
                    "HTTP/1.1 400",
                    "audit.missing-host.400"
                )
            }
        }

        Step("Expect: 100-continue gets an interim response before the body") {
            try await withAuditServer { server in
                let text = try await exchange(
                    server,
                    "POST /len HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\nExpect: 100-continue\r\n\r\n",
                    until: {
                        $0.contains(
                            "100 Continue"
                        )
                    }
                )

                try Expect.contains(
                    text,
                    "HTTP/1.1 100 Continue",
                    "audit.expect.continue"
                )
            }
        }

        Step("an untrusted peer's forwarding headers are ignored") {
            try await withAuditServer(
                trustedProxies: .none
            ) { server in
                let text = try await exchange(
                    server,
                    "GET /ip HTTP/1.1\r\nHost: x\r\nX-Forwarded-For: 6.6.6.6\r\nX-Real-IP: 6.6.6.6\r\n\r\n",
                    until: {
                        $0.contains(
                            "ip="
                        )
                    }
                )

                try Expect.contains(
                    text,
                    "ip=127.0.0.1",
                    "audit.client-ip.untrusted-peer"
                )
            }
        }

        Step("a trusted peer's chain resolves to the nearest untrusted hop") {
            try await withAuditServer(
                trustedProxies: try HTTPTrustedProxies([
                    "127.0.0.1",
                    "10.90.20.15",
                ])
            ) { server in
                let text = try await exchange(
                    server,
                    "GET /ip HTTP/1.1\r\nHost: x\r\nX-Forwarded-For: 6.6.6.6, 203.0.113.10, 10.90.20.15\r\n\r\n",
                    until: {
                        $0.contains(
                            "ip="
                        )
                    }
                )

                try Expect.contains(
                    text,
                    "ip=203.0.113.10",
                    "audit.client-ip.trusted-chain"
                )
            }
        }

        Step("graceful stop lets an in-flight request finish") {
            let server = try await SecurityTestServer.start(
                routes: auditRoutes()
            )

            let connection = SecurityTestConnection(
                port: server.port
            )

            guard await connection.start() else {
                await server.stop()
                throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
            }

            _ = await connection.send(
                "GET /slow HTTP/1.1\r\nHost: x\r\n\r\n"
            )

            await securityTestDelay(
                0.05
            )

            async let stopped: Void = server.engine.stop(
                gracePeriod: .seconds(2)
            )

            let text = await connection.receive(
                until: {
                    $0.hasSuffix(
                        "slow-done"
                    )
                },
                timeout: 1.5
            ) ?? ""

            await stopped
            connection.cancel()

            try Expect.contains(
                text,
                "slow-done",
                "audit.graceful-stop.finished"
            )

            try Expect.contains(
                text,
                "Connection: close",
                "audit.graceful-stop.close"
            )
        }
    }
}
