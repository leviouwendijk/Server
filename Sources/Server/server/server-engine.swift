import Foundation
import Network
import plate

public actor ServerEngine: Sendable {
    private let config: ServerConfig
    private let router: Router
    private let statusRegistry: HTTPStatusRegistry
    private var listener: NWListener?
    private var clients: [ServerConnectionHandler] = []
    private let logger: StandardLogger?
    
    public init(
        config: ServerConfig,
        router: Router,
        statusRegistry: HTTPStatusRegistry = GlobalHTTPStatusRegistry,
        logger: StandardLogger? = nil
    ) {
        self.config = config
        self.router = router
        self.statusRegistry = statusRegistry
        self.logger = logger
    }
    
    public func start() async throws {
        guard let nwPort = NWEndpoint.Port(rawValue: config.port) else {
            throw ServerError.invalidConfiguration("Invalid port: \(config.port)")
        }

        await logger?.log(
            "Starting server on \(config.host):\(config.port)", level: config.logLevel
        )
        
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: nwPort)
        self.listener = listener
        
        listener.newConnectionHandler = { [weak self] newConnection in
            Task {
                await self?.handleNewConnection(newConnection)
            }
        }
        
        listener.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleStateChange(state)
            }
        }
        
        listener.start(queue: DispatchQueue(label: "server.listener"))
    }
    
    public func stop() async {
        await logger?.log("Stopping server", level: .info)
        listener?.cancel()
    }
    
    private func handleNewConnection(_ connection: NWConnection) async {
        await logger?.log("New connection from \(connection.endpoint)", level: .debug)
        let handler = ServerConnectionHandler(
            connection: connection,
            router: router,
            config: config,
            statusRegistry: statusRegistry
        )
        clients.append(handler)
    }
    
    private func handleStateChange(_ state: NWListener.State) async {
        switch state {
        case .ready:
            await logger?.log("Server ready on \(config.host):\(config.port)", level: .info)
        case .failed(let error):
            await logger?.log("Server failed: \(error)", level: .error)
        case .cancelled:
            await logger?.log("Server cancelled", level: .info)
        case .waiting:
            break
        case .setup:
            await logger?.log("Server setting up...", level: .debug)
        @unknown default:
            await logger?.log("Server unknown state", level: .debug)
        }
    }
    
    // private func log(_ msg: String, level: LogLevel) {
    //     if level.rawValue >= config.logLevel.rawValue {
    //         print("[\(level.label)] \(msg)")
    //     }
    // }
}
