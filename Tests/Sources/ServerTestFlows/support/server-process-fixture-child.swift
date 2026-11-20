import Foundation
import HTTP
import Server

enum ServerProcessFixtureChild {
    private static let argument =
        "--server-fixture-child"

    private static let readinessPrefix =
        "@@testflows.ready "

    static func runIfRequested(
        arguments: [String]
    ) async throws -> Bool {
        guard arguments.dropFirst().contains(argument) else {
            return false
        }

        let host = "127.0.0.1"

        let process = ServerProcess(
            config: ServerConfig(
                name: "servtest-fixture",
                port: 0,
                host: host,
                logLevel: .error
            ),
            routes: try fixtureRoutes()
        )

        try await process.engine.start()

        guard let port = await process.engine.listenerBoundPort else {
            await process.engine.stop()

            throw ServerProcessFixtureChildError.missingBoundPort
        }

        try writeReadiness(
            ServerProcessFixtureReady(
                host: host,
                port: port
            )
        )

        switch try await process.engine.waitForTermination() {
        case .stopped:
            break

        case .failed(let message):
            throw ServerError.failedToStartListener(
                message
            )
        }

        return true
    }
}

private extension ServerProcessFixtureChild {
    static func fixtureRoutes() throws -> [Route] {
        guard let queryFormats = HTTPAcceptQuery(
            rawValue: "application/json"
        ) else {
            throw ServerProcessFixtureChildError.invalidQueryFormats
        }

        return [
            get(
                "health"
            ) {
                .ok(
                    body: "ok"
                )
            }
            .allow(
                .head
            ),

            post(
                "echo"
            ) { request in
                .ok(
                    body: request.body,
                    headers: [
                        "X-Observed-Test":
                            request.header("X-Test")
                            ?? "missing",
                    ]
                )
            },

            query(
                "search"
            ) { request in
                .ok(
                    body: "query:\(request.body)",
                    headers: [
                        "X-Observed-Content-Type":
                            request.headers.contentType
                            ?? "missing-content-type",
                    ]
                )
            }
            .acceptQuery(
                queryFormats
            ),

            get(
                "resource"
            ) {
                .ok(
                    body: "resource-get"
                )
            }
            .allow(
                .head
            ),

            query(
                "resource"
            ) {
                .ok(
                    body: "resource-query"
                )
            }
            .acceptQuery(
                queryFormats
            ),

            get(
                "one"
            ) {
                .ok(
                    body: "one"
                )
            },

            get(
                "two"
            ) {
                .ok(
                    body: "two"
                )
            },
        ]
    }

    static func writeReadiness(
        _ readiness: ServerProcessFixtureReady
    ) throws {
        let payload = try JSONEncoder().encode(
            readiness
        )

        guard let json = String(
            data: payload,
            encoding: .utf8
        ) else {
            throw ServerProcessFixtureChildError.invalidReadinessEncoding
        }

        FileHandle.standardOutput.write(
            Data(
                "\(readinessPrefix)\(json)\n".utf8
            )
        )
    }
}

private enum ServerProcessFixtureChildError:
    Error,
    Sendable
{
    case missingBoundPort
    case invalidReadinessEncoding
    case invalidQueryFormats
}
