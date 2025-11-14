import Foundation
import Network

public actor ServerEngine: Sendable {
    private let config: ServerConfig
    private let router: Router
    private let statusRegistry: HTTPStatusRegistry
    private var listener: NWListener?
    private var clients: [ServerConnectionHandler] = []
    
    public init(
        config: ServerConfig,
        router: Router,
        statusRegistry: HTTPStatusRegistry = GlobalHTTPStatusRegistry
    ) {
        self.config = config
        self.router = router
        self.statusRegistry = statusRegistry
    }
    
    public func start() async throws {
        guard let nwPort = NWEndpoint.Port(rawValue: config.port) else {
            throw ServerError.invalidConfiguration("Invalid port: \(config.port)")
        }
        
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
        listener?.cancel()
    }
    
    private func handleNewConnection(_ connection: NWConnection) async {
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
            log("Server ready on \(config.host):\(config.port)", level: .info)
        case .failed(let error):
            log("Server failed: \(error)", level: .error)
        case .cancelled:
            log("Server cancelled", level: .info)
        case .waiting:
            break
        case .setup:
            log("Server setting up...", level: .debug)
        @unknown default:
            log("Server unknown state", level: .debug)
        }
    }
    
    private func log(_ msg: String, level: LogLevel) {
        if level.rawValue >= config.logLevel.rawValue {
            print("[\(level.rawValue.uppercased())] \(msg)")
        }
    }

    public func startNotification(appName: String = "Application") -> String {
        return "Application server running on \(config.host):\(config.port)"
    }
}
