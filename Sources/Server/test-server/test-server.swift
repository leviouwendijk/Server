import Foundation
import Loggers

public struct TestServer {
    public let config: ServerConfig
    public let router: Router
    public let engine: ServerEngine
    
    /// Initialize a test server with example routes and default configuration
    public static func withTestRoutes(
        port: UInt16 = 9090,
        host: String = "127.0.0.1",
        logLevel: LogLevel = .info
    ) -> TestServer {
        let config = ServerConfig(
            port: port,
            host: host,
            logLevel: logLevel
        )
        
        let router = Router(routes: testRoutes)
        let engine = ServerEngine(config: config, router: router)
        
        return TestServer(
            config: config,
            router: router,
            engine: engine
        )
    }
    
    /// Start the server
    public func start() async throws {
        try await engine.start()
        print("🚀 Test server running on \(config.host):\(config.port)")
        print("📍 Routes available:")
        for route in router.listRoutesAsStrings() {
            print("   \(route)")
        }
    }
    
    /// Stop the server
    public func stop() async {
        await engine.stop()
        print("🛑 Test server stopped")
    }
}
