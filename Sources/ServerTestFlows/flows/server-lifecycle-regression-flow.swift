import Foundation
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverLifecycleTerminationRegressionFlow = TestFlow(
        "server.lifecycle.termination.regression",
        title: "Server startup and termination follow listener lifecycle",
        tags: [
            "lifecycle",
            "regression",
            "server",
            "startup",
            "termination",
        ]
    ) {
        Step(
            "engine start returns only after listener reaches ready"
        ) {
            let process = ServerProcess(
                config: ServerConfig(
                    name: "startup-ready-regression",
                    port: 0,
                    host: "127.0.0.1",
                    logLevel: .error
                ),
                routes: []
            )

            try await process.engine.start()

            try Expect.true(
                await process.engine.listenerIsReady,
                "server-lifecycle.start-returns-ready"
            )

            try Expect.true(
                await process.engine.listenerBoundPort != nil,
                "server-lifecycle.start-has-bound-port"
            )

            await process.engine.stop()
        }

        Step(
            "engine start binds a configured nonzero local port"
        ) {
            let port =
                try await SecurityTestServer.reservePort()

            let process = ServerProcess(
                config: ServerConfig(
                    name: "startup-fixed-port-regression",
                    port: port,
                    host: "127.0.0.1",
                    logLevel: .error
                ),
                routes: []
            )

            try await process.engine.start()

            try Expect.true(
                await process.engine.listenerIsReady,
                "server-lifecycle.fixed-port-ready"
            )

            try Expect.true(
                await process.engine.listenerBoundPort == port,
                "server-lifecycle.fixed-port-bound"
            )

            await process.engine.stop()
        }


        Step(
            "engine start throws when listener cannot bind"
        ) {
            let peer = try await SecurityTestPeer.start(
                payload: Data()
            )

            let process = ServerProcess(
                config: ServerConfig(
                    name: "startup-failure-regression",
                    port: peer.port,
                    host: "127.0.0.1",
                    logLevel: .error
                ),
                routes: []
            )

            var failed = false

            do {
                try await process.engine.start()
            } catch {
                failed = true
            }

            try Expect.true(
                failed,
                "server-lifecycle.start-throws-before-ready"
            )

            try Expect.false(
                await process.engine.listenerIsReady,
                "server-lifecycle.failed-start-not-ready"
            )

            await process.engine.stop()

            peer.stop()
        }

        Step(
            "running process remains alive until its engine is stopped"
        ) {
            let process = ServerProcess(
                config: ServerConfig(
                    name: "lifecycle-regression",
                    port: 0,
                    host: "127.0.0.1",
                    logLevel: .error
                ),
                routes: []
            )

            let finished =
                SecurityOneShot<Bool>()

            // let runTask = Task {
            //     await process.run()

            //     finished.resolve(
            //         true
            //     )
            // }
            let runTask = Task {
                try await process.throwing.run()

                finished.resolve(
                    true
                )
            }

            for _ in 0..<100 {
                if await process.engine.listenerIsReady {
                    break
                }

                if finished.isResolved {
                    break
                }

                await securityTestDelay(
                    0.01
                )
            }

            try Expect.true(
                await process.engine.listenerIsReady,
                "server-lifecycle.listener-ready"
            )

            await securityTestDelay(
                0.05
            )

            try Expect.false(
                finished.isResolved,
                "server-lifecycle.remains-running"
            )

            await process.engine.stop()

            let didFinish =
                await finished.wait(
                    timeout: 0.5,
                    fallback: false
                )

            try Expect.true(
                didFinish,
                "server-lifecycle.stops-after-engine-termination"
            )

            // _ = await runTask.result
            try await runTask.value
        }
    }
}
