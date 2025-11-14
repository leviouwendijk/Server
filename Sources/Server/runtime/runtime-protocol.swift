// import Foundation

// public protocol Runtime {
//     static var config: ServerConfig { get }
//     static var routes: [Route] { get }
//     static var router: Router { get }
//     static var engine: ServerEngine { get }

//     static func routable() -> [Route]
//     // func run() async
//     static func main() async
// }

// extension Runtime {
//     public static var config: ServerConfig { ServerConfig.externallyManagedProcess() }
//     public static var routes: [Route] { routable() }
//     public static var router: Router { Router(routes: routes) }
//     public static var engine: ServerEngine { ServerEngine(config: config, router: router) }

//     // public func run() async {
//     //     do {
//     //         try await engine.start()
//     //         try await Task.sleep(nanoseconds: UInt64.max)
//     //     } catch {
//     //         print("Failed to start server: \(error.localizedDescription)")
//     //     }
//     // }
// }
