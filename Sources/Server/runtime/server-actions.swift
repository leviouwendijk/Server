import Foundation

public struct ServerAction: Sendable {
    public let name: String
    private let action: @Sendable () async -> Void

    public init(
        name: String,
        action: @escaping @Sendable () async -> Void
    ) {
        self.name = name
        self.action = action
    }

    public init(
        name: String,
        sync action: @escaping @Sendable () -> Void
    ) {
        self.name = name
        self.action = {
            action()
        }
    }

    internal func perform() async {
        await action()
    }
}

public struct ServerActions: Sendable {
    public let launch: [ServerAction]
    public let termination: [ServerAction]
    
    public init(
        launch: [ServerAction] = [],
        termination: [ServerAction] = []
    ) {
        self.launch = launch
        self.termination = termination
    }

    public static let empty = Self()
}
