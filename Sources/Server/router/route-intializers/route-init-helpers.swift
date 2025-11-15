import Foundation

internal func joinPath(_ components: [String]) -> String {
    components.isEmpty ? "/" : "/" + components.joined(separator: "/")
}
