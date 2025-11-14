import Foundation
import Network

private actor ResponseActor: Sendable {
    var result: Result<HTTPResponse, ServerError>?
    
    func setSuccess(_ response: HTTPResponse) {
        result = .success(response)
    }
    
    func setFailure(_ error: ServerError) {
        result = .failure(error)
    }
    
    func getResult() -> Result<HTTPResponse, ServerError>? {
        result
    }
}

public struct HTTPClient: Sendable {
    private let config: HTTPClientConfig
    
    public init(config: HTTPClientConfig = .init()) {
        self.config = config
    }
    
    // MARK: - Main Send Method
    
    public func send(
        method: HTTPMethod,
        path: String,
        headers: [String: String] = [:],
        body: String? = nil,
        auth: RequestAuth = .none,
    ) async throws -> HTTPResponse {
        let responseActor = ResponseActor()
        
        let conn = NWConnection(
            host: NWEndpoint.Host(config.host),
            port: NWEndpoint.Port(rawValue: config.port)!,
            using: .tcp
        )
        
        // Build headers with auth
        var allHeaders = headers
        switch auth {
        case .none:
            break
        case .bearer(let token):
            allHeaders["Authorization"] = "Bearer \(token)"
        case .custom(let key, let value):
            allHeaders[key] = value
        }
        
        let wireRequest = buildWireRequest(
            host: config.host,
            method: method,
            path: path,
            headers: allHeaders,
            body: body
        )
        
        if config.debug {
            print("DEBUG: Creating connection to \(config.host):\(config.port)")
        }

        let handler = RequestConnectionHandler(
            connection: conn,
            onSuccess: { response in
                if config.debug {
                    print("DEBUG: Got success response")
                }
                Task {
                    await responseActor.setSuccess(response)
                }
            },
            onError: { error in
                if config.debug {
                    print("DEBUG: Got error: \(error)")
                }
                Task {
                    await responseActor.setFailure(error)
                }
            }
        )

        conn.stateUpdateHandler = { [weak handler] state in
            print("DEBUG: Connection state changed: \(state)")
            switch state {
            case .ready:
                if config.debug {
                    print("DEBUG: Connection ready, sending request")
                }
                handler?.send(wireRequest)
            case .failed(let error):
                if config.debug {
                    print("DEBUG: Connection failed: \(error)")
                }
                Task {
                    await responseActor.setFailure(.connectionFailed(error.localizedDescription))
                }
            default:
                if config.debug {
                    print("DEBUG: Connection state: \(state)")
                }
            }
        }

        if config.debug {
            print("DEBUG: Starting connection")
        }
        conn.start(queue: DispatchQueue(label: "http-client"))
        
        // Async timeout with polling
        let deadline = Date().addingTimeInterval(config.timeout)
        while await responseActor.getResult() == nil {
            if Date() > deadline {
                conn.cancel()
                throw ServerError.connectionFailed("Request timed out")
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        
        return try (await responseActor.getResult())!.get()
    }
    
    // MARK: - Convenience Methods
    
    public func get(
        _ path: String,
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await send(method: .get, path: path, auth: auth)
    }
    
    public func post(
        _ path: String,
        body: String? = nil,
        headers: [String: String] = [:],
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await send(method: .post, path: path, headers: headers, body: body, auth: auth)
    }
    
    public func put(
        _ path: String,
        body: String? = nil,
        headers: [String: String] = [:],
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await send(method: .put, path: path, headers: headers, body: body, auth: auth)
    }
    
    public func delete(
        _ path: String,
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await send(method: .delete, path: path, auth: auth)
    }
    
    public func patch(
        _ path: String,
        body: String? = nil,
        headers: [String: String] = [:],
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await send(method: .patch, path: path, headers: headers, body: body, auth: auth)
    }
}
