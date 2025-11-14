import Foundation

public struct ManagedAppRuntime {
    public static func run(routes: [Route]) async {
        let config = ServerConfig.externallyManagedProcess()
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
