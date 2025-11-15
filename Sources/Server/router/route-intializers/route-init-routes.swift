import Foundation

// Route DSL Container
public func routes(@RouteBuilder _ builder: () -> [Route]) -> [Route] {
    builder()
}
