import Foundation
import HTTP

public struct TestClient {
    public let config: HTTPClientConfig
    private let client: HTTPClient
    
    /// Initialize a test client with default configuration
    public static func withDefaults(
        host: String = "127.0.0.1",
        port: UInt16 = 9090,
        timeout: TimeInterval = 5,
        debug: Bool = true
    ) -> TestClient {
        let config = HTTPClientConfig(host: host, port: port, timeout: timeout, debug: debug)
        let client = HTTPClient(config: config)
        return TestClient(config: config, client: client)
    }
    
    /// Make a GET request
    public func get(
        _ path: String,
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await client.get(path, auth: auth)
    }
    
    /// Make a POST request
    public func post(
        _ path: String,
        body: String? = nil,
        headers: [String: String] = [:],
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await client.post(path, body: body, headers: headers, auth: auth)
    }
    
    /// Make a PUT request
    public func put(
        _ path: String,
        body: String? = nil,
        headers: [String: String] = [:],
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await client.put(path, body: body, headers: headers, auth: auth)
    }
    
    /// Make a DELETE request
    public func delete(
        _ path: String,
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await client.delete(path, auth: auth)
    }
    
    /// Make a PATCH request
    public func patch(
        _ path: String,
        body: String? = nil,
        headers: [String: String] = [:],
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await client.patch(path, body: body, headers: headers, auth: auth)
    }
    
    // MARK: - Convenience Static Methods
    
    /// Make a GET request with default client configuration
    public static func get(
        _ path: String,
        host: String = "127.0.0.1",
        port: UInt16 = 9090,
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        let client = TestClient.withDefaults(host: host, port: port)
        return try await client.get(path, auth: auth)
    }
    
    /// Make a POST request with default client configuration
    public static func post(
        _ path: String,
        body: String? = nil,
        headers: [String: String] = [:],
        host: String = "127.0.0.1",
        port: UInt16 = 9090,
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        let client = TestClient.withDefaults(host: host, port: port)
        return try await client.post(path, body: body, headers: headers, auth: auth)
    }
    
    /// Make a PUT request with default client configuration
    public static func put(
        _ path: String,
        body: String? = nil,
        headers: [String: String] = [:],
        host: String = "127.0.0.1",
        port: UInt16 = 9090,
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        let client = TestClient.withDefaults(host: host, port: port)
        return try await client.put(path, body: body, headers: headers, auth: auth)
    }
    
    /// Make a DELETE request with default client configuration
    public static func delete(
        _ path: String,
        host: String = "127.0.0.1",
        port: UInt16 = 9090,
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        let client = TestClient.withDefaults(host: host, port: port)
        return try await client.delete(path, auth: auth)
    }
    
    /// Make a PATCH request with default client configuration
    public static func patch(
        _ path: String,
        body: String? = nil,
        headers: [String: String] = [:],
        host: String = "127.0.0.1",
        port: UInt16 = 9090,
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        let client = TestClient.withDefaults(host: host, port: port)
        return try await client.patch(path, body: body, headers: headers, auth: auth)
    }
}
