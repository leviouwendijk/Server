import Foundation

public struct HTTPHeaders: Sendable {
    private var storage: [(String, String)] = []
    
    public init() {}
    
    public init(_ dict: [String: String]) {
        self.storage = dict.map { ($0.key, $0.value) }
    }
    
    /// Set or override a header (case-insensitive key)
    public mutating func set(_ name: String, _ value: String) {
        let lower = name.lowercased()
        storage.removeAll { $0.0.lowercased() == lower }
        storage.append((name, value))
    }
    
    /// Get a header value (case-insensitive)
    public func get(_ name: String) -> String? {
        let lower = name.lowercased()
        return storage.first { $0.0.lowercased() == lower }?.1
    }
    
    /// Get all headers as dictionary
    public func toDictionary() -> [String: String] {
        var dict: [String: String] = [:]
        for (key, value) in storage {
            dict[key] = value
        }
        return dict
    }
    
    /// Iterate over headers
    public func forEach(_ body: (String, String) -> Void) {
        for (key, value) in storage {
            body(key, value)
        }
    }
    
    /// Get all header lines for serialization
    public func lines() -> [String] {
        storage.map { "\($0.0): \($0.1)" }
    }
}
