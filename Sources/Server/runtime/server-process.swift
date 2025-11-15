import Foundation

public struct ServerProcess: Sendable {
    public let config: ServerConfig
    public let routes: [Route]
    public let router: Router
    public let engine: ServerEngine

    public init(
        config: ServerConfig = ServerConfig.externallyManagedProcess(),
        routes: [Route]
    ) {
        self.config = config
        self.routes = routes
        self.router = Router(routes: routes)
        self.engine = ServerEngine(config: config, router: router)
    }

    /// Instance entry point
    public func run() async {
        do {
            try await engine.start()
            try await Task.sleep(nanoseconds: UInt64.max)
        } catch {
            print("Failed to start server: \(error.localizedDescription)")
        }
    }

    /// Static entry point
    public static func run(
        config: ServerConfig = ServerConfig.externallyManagedProcess(),
        routes: [Route]
    ) async {
        let router = Router(routes: routes)
        let engine = ServerEngine(config: config, router: router)
        
        do {
            try await engine.start()
            try await Task.sleep(nanoseconds: UInt64.max)
        } catch {
            print("Failed to start server: \(error.localizedDescription)")
        }
    }
}

// The above function abstracts:
// 
// @main
// struct AppRuntime {
//     static func main() async {
//         let config = ServerConfig.externallyManagedProcess() // <-- assuming passage of env variables (APP_NAME, PORT, HOST?, LOG_LEVEL?)

//         let routes = routes()
//         let router = Router(routes: routes)
//         let engine = ServerEngine(config: config, router: router)

//         do {
//             try await engine.start()
//             try await Task.sleep(nanoseconds: UInt64.max)
//         } catch {
//             print("Failed to start server: \(error.localizedDescription)")
//         }
//     }
// }
//
// Which allows you to not worry about instantiating the router or engine,
// considering this is being done purely from the config + routes anyway.
