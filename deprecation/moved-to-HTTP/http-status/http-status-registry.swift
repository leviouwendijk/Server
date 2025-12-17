import Foundation

/// Global HTTP status registry accessible throughout the application
public let GlobalHTTPStatusRegistry = HTTPStatusRegistry()

public extension HTTPStatusRegistry {
    /// Convenience factory for creating the global registry
    static let global = HTTPStatusRegistry()
}

/// Thread-safe actor for managing HTTP status codes
public actor HTTPStatusRegistry: Sendable {
    private var customStatuses: [Int: HTTPStatus] = [:]
    
    public init() {}
    
    /// Register a custom HTTP status code
    public func register(_ status: HTTPStatus) {
        customStatuses[status.code] = status
    }
    
    /// Register multiple status codes at once
    public func registerBatch(_ statuses: [HTTPStatus]) {
        for status in statuses {
            customStatuses[status.code] = status
        }
    }
    
    /// Unregister a status code
    public func unregister(code: Int) {
        customStatuses.removeValue(forKey: code)
    }
    
    /// Retrieve a status by code, with fallback to defaults
    public func resolve(code: Int) -> HTTPStatus {
        if let custom = customStatuses[code] {
            return custom
        }
        
        return HTTPStatus.defaultFor(code: code)
    }
    
    /// Check if a custom status is registered
    public func hasCustomStatus(code: Int) -> Bool {
        customStatuses[code] != nil
    }
    
    /// Get snapshot of all registered custom statuses
    public func snapshot() -> [Int: HTTPStatus] {
        customStatuses
    }
    
    /// Clear all custom statuses
    public func clearCustom() {
        customStatuses.removeAll()
    }
    
    /// Get count of custom statuses
    public func customCount() -> Int {
        customStatuses.count
    }
}
