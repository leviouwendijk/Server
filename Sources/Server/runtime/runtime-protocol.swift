import Foundation

public protocol Runtime {
    static var config: ServerConfig { get }
    static var routes: [Route] { get }
    static var router: Router { get }
    static var engine: ServerEngine { get }

    static func routable() -> [Route]
    static func run() async
}

extension Runtime {
    public static var config: ServerConfig { ServerConfig.externallyManagedProcess() }
    public static var routes: [Route] { routable() }
    public static var router: Router { Router(routes: self.routes) }
    public static var engine: ServerEngine { ServerEngine(config: self.config, router: self.router) }

    public static func run() async {
        do {
            try await self.engine.start()
            try await Task.sleep(nanoseconds: UInt64.max)
        } catch {
            print("Failed to start server: \(error.localizedDescription)")
        }
    }
}
