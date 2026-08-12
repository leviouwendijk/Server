import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverExecutionTimeoutRegressionFlow = TestFlow(
        "server.execution-timeout.regression",
        title: "Configured route execution deadline returns Gateway Timeout",
        tags: [
            "execution",
            "regression",
            "server",
            "timeout",
        ]
    ) {
        Step(
            "configured execution deadline returns 504 before a slow route completes"
        ) {
            let server = try await SecurityTestServer.start(
                timeouts: ServerTimeouts(
                    idle: .seconds(1),
                    headers: .seconds(1),
                    content: .seconds(1),
                    execution: .milliseconds(100)
                ),
                routes: [
                    get(
                        "execution-timeout"
                    ) {
                        do {
                            try await Task.sleep(
                                for: .seconds(1)
                            )
                        } catch {
                        }

                        return .ok(
                            body: "late-response"
                        )
                    }
                ]
            )

            let connection =
                SecurityTestConnection(
                    port: server.port
                )

            do {
                let connected =
                    await connection.start()

                try Expect.true(
                    connected,
                    "execution-timeout.connection-ready"
                )

                let sent =
                    await connection.send(
                        "GET /execution-timeout HTTP/1.1\r\nHost: localhost\r\n\r\n"
                    )

                try Expect.true(
                    sent,
                    "execution-timeout.request-sent"
                )

                let response =
                    await connection.receive(
                        until: {
                            $0.contains(
                                "HTTP/1.1 504"
                            )
                        },
                        timeout: 0.5
                    )

                try Expect.true(
                    response?.contains(
                        "HTTP/1.1 504"
                    ) == true,
                    "execution-timeout.gateway-timeout"
                )
            } catch {
                connection.cancel()

                await server.stop()

                throw error
            }

            connection.cancel()

            await server.stop()
        }
    }
}
