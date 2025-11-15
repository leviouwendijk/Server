import Foundation
import plate

public struct ServerProcess: Sendable {
    public let config: ServerConfig
    public let routes: [Route]
    public let router: Router
    public let engine: ServerEngine
    public let logger: StandardLogger?

    public init(
        config: ServerConfig = ServerConfig.externallyManagedProcess(),
        routes: [Route],

        statusRegistry: HTTPStatusRegistry = GlobalHTTPStatusRegistry,
        logger: StandardLogger? = nil
    ) {
        self.config = config
        self.routes = routes
        self.router = Router(routes: routes)
        self.engine = ServerEngine(
            config: config,
            router: router,
            statusRegistry: statusRegistry,
            logger: logger
        )
        self.logger = logger
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
        routes: [Route],

        statusRegistry: HTTPStatusRegistry = GlobalHTTPStatusRegistry,
        logger: StandardLogger? = nil
    ) async {
        let router = Router(routes: routes)
        let engine = ServerEngine(
            config: config,
            router: router,
            statusRegistry: statusRegistry,
            logger: logger
        )
        
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

// That means you can launch runtime in as few steps as:

// import Server
//
// @main
// struct AppRuntime {
//     static func main() async {
//         await ServerProcess.run(routes: routes())
//     }
// }

// Alternatively, you can hydrate an instance and run that without static entry:
// This makes config (ServerConfig instance) reusable, say, in your routes
// 
// You *could* make the ServerProcess a global constant:
//
// let process = ServerProcess(routes: routes())
// 
// But this requires that your routes() func you implement does **not** throw.
// 
//
// If you **do** want to make it throw, make main() async throws, define process inside it:

// import Server
//
// let config = ServerConfig.externallyManagedProcess()
//
// @main
// struct AppRuntime {
//     static func main() async throws {
//         let process = ServerProcess(
//             config: config,
//             routes: try routes()
//         )
//         await process.run() // <-- instance method instead of static accessible
//     }
// }

// This way, config is still globally reusable and accessible.
// But the runtime is able to throw on try routes().
