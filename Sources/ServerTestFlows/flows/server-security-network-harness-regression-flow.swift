import Foundation
import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let securityNetworkHarnessRegressionFlow = TestFlow(
        "security.harness.network.regression",
        title: "Security network harness starts deterministic loopback peers",
        tags: [
            "security",
            "harness",
            "network",
            "integration",
            "regression",
        ]
    ) {
        Step(
            "SecurityTestServer reaches listener ready state and serves a request"
        ) {
            let server = try await SecurityTestServer.start(
                routes: [
                    get("harness") {
                        .ok(
                            body: "harness-server-ok"
                        )
                    }
                ]
            )

            let connection = SecurityTestConnection(
                port: server.port
            )

            do {
                let connected =
                    await connection.start()

                try Expect.true(
                    connected,
                    "security-harness.server.connection-ready"
                )

                let sent = await connection.send(
                    "GET /harness HTTP/1.1\r\nHost: localhost\r\n\r\n"
                )

                try Expect.true(
                    sent,
                    "security-harness.server.request-sent"
                )

                let response = await connection.receive(
                    until: {
                        $0.contains(
                            "harness-server-ok"
                        )
                    },
                    timeout: 1
                )

                try Expect.true(
                    response?.contains(
                        "harness-server-ok"
                    ) == true,
                    "security-harness.server.response-received"
                )
            } catch {
                connection.cancel()
                await server.stop()

                throw error
            }

            connection.cancel()

            await server.stop()
        }

        Step(
            "HTTPClient wire request carries the explicit HTTP version"
        ) {
            let wire = try buildWireRequest(
                host: "example.com",
                method: .get,
                path: "/",
                headers: [:],
                body: nil
            )

            try Expect.true(
                wire.hasPrefix(
                    "GET / HTTP/1.1\r\nHost: example.com\r\n"
                ),
                "security-harness.client.http11-request-line"
            )
        }

        Step(
            "SecurityTestPeer reaches listener ready state and serves HTTPClient"
        ) {
            let peer = try await SecurityTestPeer.start(
                payload: Data(
                    "HTTP/1.1 200 OK\r\nContent-Length: 15\r\n\r\nharness-peer-ok".utf8
                )
            )

            let client = HTTPClient(
                config: HTTPClientConfig(
                    host: "127.0.0.1",
                    port: peer.port,
                    timeout: 1,
                    debug: false
                )
            )

            do {
                let response = try await client.get(
                    "/"
                )

                try Expect.equal(
                    response.status.code,
                    200,
                    "security-harness.peer.status"
                )

                try Expect.equal(
                    response.body,
                    "harness-peer-ok",
                    "security-harness.peer.body"
                )
            } catch {
                peer.stop()

                throw error
            }

            peer.stop()
        }

        Step(
            "HTTPClient decodes chunked response across receive windows"
        ) {
            let peer = try await SecurityTestPeer.start(
                payloads: [
                    Data(
                        "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunk".utf8
                    ),
                    Data(
                        "ed\r\n\r\n5\r\nhel".utf8
                    ),
                    Data(
                        "lo\r\n6\r\n wor".utf8
                    ),
                    Data(
                        "ld\r\n0\r\nX-Trace: done\r\n".utf8
                    ),
                    Data(
                        "\r\n".utf8
                    ),
                ],
                interPayloadDelay: 0.025
            )

            let client = HTTPClient(
                config: HTTPClientConfig(
                    host: "127.0.0.1",
                    port: peer.port,
                    timeout: 2,
                    debug: false
                )
            )

            do {
                let response = try await client.get(
                    "/"
                )

                try Expect.equal(
                    response.status.code,
                    200,
                    "security-harness.client.chunked.status"
                )

                try Expect.equal(
                    response.body,
                    "hello world",
                    "security-harness.client.chunked.body"
                )

                try Expect.equal(
                    response.trailers[
                        "X-Trace"
                    ],
                    "done",
                    "security-harness.client.chunked.trailer"
                )
            } catch {
                peer.stop()

                throw error
            }

            peer.stop()
        }

        Step(
            "HTTPClient TCP with TLS rejects a plaintext peer"
        ) {
            let peer = try await SecurityTestPeer.start(
                payload: Data(
                    "HTTP/1.1 200 OK\r\nContent-Length: 17\r\n\r\nplaintext-peer-ok".utf8
                )
            )

            let client = HTTPClient(
                config: HTTPClientConfig(
                    host: "127.0.0.1",
                    port: peer.port,
                    transport: .tcp(
                        security: .tls()
                    ),
                    timeout: 1,
                    debug: false
                )
            )

            var rejected = false

            do {
                _ = try await client.get(
                    "/"
                )
            } catch {
                rejected = true
            }

            peer.stop()

            try Expect.true(
                rejected,
                "security-harness.client.tcp-tls-rejects-plaintext"
            )
        }
    }
}
