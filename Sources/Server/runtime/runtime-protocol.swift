import Foundation

public protocol Runtime {
    var config: ServerConfig { get }
    var routes: [Route] { get }
    var router: Router { get }
    var engine: ServerEngine { get }

    func routable() -> [Route]
    func main() async
}

extension Runtime {
    var config: ServerConfig { ServerConfig.externallyManagedProcess() }
    var routes: [Route] { routable() }
    var router: Router { Router(routes: routes) }
    var engine: ServerEngine { ServerEngine(config: config, router: router) }

    func main() async {
        do {
            try await engine.start()
            try await Task.sleep(nanoseconds: UInt64.max)
        } catch {
            print("Failed to start server: \(error.localizedDescription)")
        }
    }
}
