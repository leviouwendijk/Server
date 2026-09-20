import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverExecutionTimeoutRegressionFlow = TestFlow(
        "server.execution-timeout.regression",
        title: "Configured route execution deadline returns Service Unavailable",
        tags: [
            "execution",
            "regression",
            "server",
            "timeout",
        ]
    ) {
        Step(
            "configured execution deadline returns 503 before a slow route completes"
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
                                "HTTP/1.1 503"
                            )
                        },
                        timeout: 0.5
                    )

                try Expect.true(
                    response?.contains(
                        "HTTP/1.1 503"
                    ) == true,
                    "execution-timeout.service-unavailable"
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
