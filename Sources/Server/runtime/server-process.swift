import Foundation
import HTTP
import Loggers

public struct ServerProcess: Sendable {
    public let config: ServerConfig
    public let routes: [Route]
    public let router: Router
    public let engine: ServerEngine
    public let logger: StandardLogger?
    public let actions: ServerActions

    public init(
        config: ServerConfig = ServerConfig.externallyManagedProcess(),
        routes: [Route],
        unmatched: RouteUnmatchedHandler? = nil,

        statusRegistry: HTTPStatusRegistry = GlobalHTTPStatusRegistry,
        logger: StandardLogger? = nil,

        activity: HTTPActivityCallback? = nil,
        actions: ServerActions = .empty
    ) {
        let router = Router(
            routes: routes,
            methods: config.security.methods,
            json: config.json,
            unmatched: unmatched
        )

        self.config = config
        self.routes = routes
        self.router = router
        self.engine = ServerEngine(
            config: config,
            router: router,
            statusRegistry: statusRegistry,
            logger: logger,
            activityCallback: activity
        )
        self.logger = logger
        self.actions = actions
    }

    /// Instance entry point
    public func run() async {
        do {
            for action in actions.launch {
                await logger?.log("Running launch action: \(action.name)", level: .info)
                await action.perform()
            }

            let signals = installShutdownSignals()

            try await engine.start()

            defer {
                signals.forEach {
                    $0.cancel()
                }
            }

            switch try await engine.waitForTermination() {
            case .stopped:
                break

            case .failed(
                let message
            ):
                throw ServerError.failedToStartListener(
                    message
                )
            }
        } catch is CancellationError {
            await logger?.log("Server process cancelled", level: .debug)
        } catch {
            if let logger {
                await logger.log("Failed to run server process: \(error.localizedDescription)", level: .error)
            } else {
                print("Failed to run server process: \(error.localizedDescription)")
            }
        }

        await terminate()
    }

    /// Static entry point
    public static func run(
        config: ServerConfig = ServerConfig.externallyManagedProcess(),
        routes: [Route],
        statusRegistry: HTTPStatusRegistry = GlobalHTTPStatusRegistry,
        logger: StandardLogger? = nil,
        activity: HTTPActivityCallback? = nil,
        actions: ServerActions = .empty
    ) async {
        let process = ServerProcess(
            config: config,
            routes: routes,
            statusRegistry: statusRegistry,
            logger: logger,
            activity: activity,
            actions: actions
        )

        await process.run()
    }

    /// SIGINT (PM2's stop signal) and SIGTERM start a graceful stop: in-flight requests
    /// finish within `config.timeouts.shutdown`, then `run()` returns and termination
    /// actions run. Keep PM2's `kill_timeout` above that grace period.
    func installShutdownSignals() -> [DispatchSourceSignal] {
        [SIGINT, SIGTERM].map { number in
            signal(
                number,
                SIG_IGN
            )

            let source = DispatchSource.makeSignalSource(
                signal: number,
                queue: .global()
            )

            let engine = engine
            let grace = config.timeouts.shutdown

            source.setEventHandler {
                Task {
                    await engine.stop(
                        gracePeriod: grace
                    )
                }
            }

            source.resume()

            return source
        }
    }

    public func terminate() async {
        await logger?.log("Stopping server process", level: .info)
        await engine.stop(
            gracePeriod: config.timeouts.shutdown
        )

        for action in actions.termination.reversed() {
            await logger?.log("Running termination action: \(action.name)", level: .info)
            await action.perform()
        }
    }
}

extension ServerProcess {
    public struct Throwing: Sendable {
        private let process: ServerProcess

        internal init(
            process: ServerProcess
        ) {
            self.process = process
        }

        public func run() async throws {
            do {
                for action in process.actions.launch {
                    await process.logger?.log(
                        "Running launch action: \(action.name)",
                        level: .info
                    )

                    await action.perform()
                }

                let signals = process.installShutdownSignals()

                try await process.engine.start()

                defer {
                    signals.forEach {
                        $0.cancel()
                    }
                }

                switch try await process.engine.waitForTermination() {
                case .stopped:
                    break

                case .failed(
                    let message
                ):
                    throw ServerError.failedToStartListener(
                        message
                    )
                }
            } catch is CancellationError {
                await process.logger?.log(
                    "Server process cancelled",
                    level: .debug
                )

                await process.terminate()

                throw CancellationError()
            } catch {
                await process.logger?.log(
                    "Failed to run server process: \(error.localizedDescription)",
                    level: .error
                )

                await process.terminate()

                throw error
            }

            await process.terminate()
        }

        public static func run(
            config: ServerConfig = ServerConfig.externallyManagedProcess(),
            routes: [Route],
            statusRegistry: HTTPStatusRegistry = GlobalHTTPStatusRegistry,
            logger: StandardLogger? = nil,
            activity: HTTPActivityCallback? = nil,
            actions: ServerActions = .empty
        ) async throws {
            let process = ServerProcess(
                config: config,
                routes: routes,
                statusRegistry: statusRegistry,
                logger: logger,
                activity: activity,
                actions: actions
            )

            try await process.throwing.run()
        }
    }

    public var throwing: Throwing {
        Throwing(
            process: self
        )
    }
}
