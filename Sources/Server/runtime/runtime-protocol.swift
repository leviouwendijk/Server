import Foundation

public protocol Runtime {
    var config: ServerConfig { get }
    var routes: [Route] { get }
    var router: Router { get }
    var engine: ServerEngine { get }

    func routable() -> [Route]
    // func run() async
    static func main() async
}

extension Runtime {
    public var config: ServerConfig { ServerConfig.externallyManagedProcess() }
    public var routes: [Route] { routable() }
    public var router: Router { Router(routes: routes) }
    public var engine: ServerEngine { ServerEngine(config: config, router: router) }

    // public func run() async {
    //     do {
    //         try await engine.start()
    //         try await Task.sleep(nanoseconds: UInt64.max)
    //     } catch {
    //         print("Failed to start server: \(error.localizedDescription)")
    //     }
    // }
}
