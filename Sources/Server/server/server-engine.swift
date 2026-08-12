import Foundation
import HTTP
import Network
import Loggers

public actor ServerEngine: Sendable {
    public enum Termination: Sendable, Equatable {
        case stopped
        case failed(String)
    }

    private enum Startup: Sendable, Equatable {
        case ready
        case failed(String)
    }

    private let config: ServerConfig
    private let router: Router
    private let statusRegistry: HTTPStatusRegistry

    private var listener: NWListener?
    private var listenerReady = false
    private var listenerFailure: String?

    private var startup: Startup?
    private var startupWaiters: [
        CheckedContinuation<Startup, Never>
    ] = []

    private var termination: Termination?
    private var terminationWaiters: [
        CheckedContinuation<Termination, Never>
    ] = []

    private var clients: [UUID: ServerConnectionHandler] = [:]

    private let logger: StandardLogger?
    private let activityCallback: HTTPActivityCallback?
    
    public init(
        config: ServerConfig,
        router: Router,
        statusRegistry: HTTPStatusRegistry = GlobalHTTPStatusRegistry,
        logger: StandardLogger? = nil,
        activityCallback: HTTPActivityCallback? = nil
    ) {
        self.config = config
        self.router = router
        self.statusRegistry = statusRegistry
        self.logger = logger ?? (try? StandardLogger(name: config.name))
        self.activityCallback = activityCallback
    }
    
    public func start() async throws {
        guard listener == nil else {
            throw ServerError.invalidConfiguration(
                "Server listener has already been started"
            )
        }

        guard let nwPort = NWEndpoint.Port(
            rawValue: config.port
        ) else {
            throw ServerError.invalidConfiguration(
                "Invalid port: \(config.port)"
            )
        }

        listenerReady = false
        listenerFailure = nil

        startup = nil
        termination = nil

        await logger?.log(
            "Starting server on \(config.host):\(config.port)",
            level: config.logLevel
        )

        let params = NWParameters.tcp

        params.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host(
                config.host
            ),
            port: nwPort
        )

        let listener = try NWListener(
            using: params,
            // on: nwPort
        )

        self.listener = listener

        listener.newConnectionHandler = { [weak self] newConnection in
            Task {
                await self?.handleNewConnection(
                    newConnection
                )
            }
        }

        listener.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleStateChange(
                    state
                )
            }
        }

        listener.start(
            queue: DispatchQueue(
                label: "server.listener"
            )
        )

        let result = await withTaskCancellationHandler {
            await waitForStartupSignal()
        } onCancel: {
            Task {
                await self.stop()
            }
        }

        try Task.checkCancellation()

        switch result {
        case .ready:
            return

        case .failed(
            let message
        ):
            throw ServerError.failedToStartListener(
                message
            )
        }
    }
    
    public func stop() async {
        await logger?.log(
            "Stopping server",
            level: .info
        )

        listener?.cancel()
        listener = nil

        signalStartup(
            .failed(
                "Server stopped before listener became ready"
            )
        )

        signalTermination(
            .stopped
        )

        let active = Array(
            clients.values
        )

        clients.removeAll()

        for handler in active {
            handler.cancel()
        }
    }

    public func waitForTermination() async throws -> Termination {
        let result = await withTaskCancellationHandler {
            await waitForTerminationSignal()
        } onCancel: {
            Task {
                await self.stop()
            }
        }

        try Task.checkCancellation()

        return result
    }

    package var retainedConnectionHandlerCount: Int {
        clients.count
    }

    package func maximumPendingOperationCount() async -> Int {
        let active = Array(
            clients.values
        )

        var maximum = 0

        for handler in active {
            maximum = max(
                maximum,
                await handler.pendingOperationCount()
            )
        }

        return maximum
    }

    package var listenerIsReady: Bool {
        listenerReady
    }

    package var listenerBoundPort: UInt16? {
        listener?.port?.rawValue
    }

    package var listenerFailureDescription: String? {
        listenerFailure
    }
    
    private func handleNewConnection(
        _ connection: NWConnection
    ) async {
        await logger?.log(
            "New connection from \(connection.endpoint)",
            level: .debug
        )

        if let maximum = config.maxConnections,
           clients.count >= maximum {
            await logger?.log(
                "Rejecting connection because maxConnections \(maximum) has been reached",
                level: .debug
            )

            connection.cancel()
            return
        }

        let id = UUID()

        let handler = ServerConnectionHandler(
            id: id,
            connection: connection,
            router: router,
            config: config,
            statusRegistry: statusRegistry,
            onTermination: { [weak self] id in
                Task {
                    await self?.removeConnection(
                        id
                    )
                }
            },
            activityCallback: activityCallback
        )

        clients[id] = handler
    }

    private func removeConnection(
        _ id: UUID
    ) {
        clients.removeValue(
            forKey: id
        )
    }

    private func waitForStartupSignal() async -> Startup {
        if let startup {
            return startup
        }

        return await withCheckedContinuation { continuation in
            startupWaiters.append(
                continuation
            )
        }
    }

    private func signalStartup(
        _ value: Startup
    ) {
        guard startup == nil else {
            return
        }

        startup = value

        let waiters =
            startupWaiters

        startupWaiters.removeAll()

        for waiter in waiters {
            waiter.resume(
                returning: value
            )
        }
    }


    private func waitForTerminationSignal() async -> Termination {
        if let termination {
            return termination
        }

        return await withCheckedContinuation { continuation in
            terminationWaiters.append(
                continuation
            )
        }
    }

    private func signalTermination(
        _ value: Termination
    ) {
        guard termination == nil else {
            return
        }

        termination = value

        let waiters =
            terminationWaiters

        terminationWaiters.removeAll()

        for waiter in waiters {
            waiter.resume(
                returning: value
            )
        }
    }

    private func handleStateChange(_ state: NWListener.State) async {
        switch state {
        case .ready:
            listenerReady = true
            listenerFailure = nil

            signalStartup(
                .ready
            )

            await logger?.log(
                "Server ready on \(config.host):\(config.port)",
                level: .info
            )

        case .failed(let error):
            let message =
                error.localizedDescription

            listenerReady = false
            listenerFailure = message

            signalStartup(
                .failed(
                    message
                )
            )

            signalTermination(
                .failed(
                    message
                )
            )

            await logger?.log(
                "Server failed: \(error)",
                level: .error
            )

        case .cancelled:
            listenerReady = false

            signalStartup(
                .failed(
                    "Listener cancelled before becoming ready"
                )
            )

            signalTermination(
                .stopped
            )

            await logger?.log(
                "Server cancelled",
                level: .info
            )

        case .waiting:
            listenerReady = false

        case .setup:
            listenerReady = false

            await logger?.log(
                "Server setting up...",
                level: .debug
            )

        @unknown default:
            listenerReady = false

            await logger?.log(
                "Server unknown state",
                level: .debug
            )
        }
    }
    
    // private func log(_ msg: String, level: LogLevel) {
    //     if level.rawValue >= config.logLevel.rawValue {
    //         print("[\(level.label)] \(msg)")
    //     }
    // }
}
