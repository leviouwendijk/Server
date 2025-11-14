import Foundation

public struct ServerRuntime {
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
