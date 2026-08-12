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
    }
}
