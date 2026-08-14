import Foundation
import HTTP
import Network

private extension HTTPClientConfig.Transport {
    var parameters: NWParameters {
        switch self {
        case .tcp(let security):
            switch security {
            case .plaintext:
                return .tcp

            case .tls:
                return .tls
            }
        }
    }
}

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
    
    // Server/Sources/Server/Client/HTTPClient.swift
    public func send(
        method: HTTPMethod,
        path: String,
        headers: [String: String] = [:],
        body: String? = nil,
        auth: RequestAuth = .none,
    ) async throws -> HTTPResponse {
        @Sendable
        func timestamp() -> String { 
            let fmt = ISO8601DateFormatter() 
            return fmt.string(from: Date()) 
        }
        
        @Sendable
        func log(_ msg: String) {
            if config.debug {
                print("[\(timestamp())] HTTPClient: \(msg)")
            }
        }
        
        let responseActor = ResponseActor()
        
        let conn = NWConnection(
            host: NWEndpoint.Host(config.host),
            port: NWEndpoint.Port(rawValue: config.port)!,
            using: config.transport.parameters
        )
        
        log("Creating connection to \(config.host):\(config.port)")
        
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
        
        let wire = try buildWireRequest(
            host: config.host,
            method: method,
            path: path,
            headers: allHeaders,
            body: body
        )

        log(
            "Prepared \(method.rawValue) request (\(wire.utf8.count) bytes)"
        )

        let handler = RequestConnectionHandler(
            connection: conn,
            requestMethod: method,
            policies: config.policies,
            onSuccess: { response in
                log(
                    "Handler received success response: \(response.status.code)"
                )

                Task {
                    await responseActor.setSuccess(
                        response
                    )
                }
            },
            onError: { error in
                log(
                    "Handler received error: \(error)"
                )

                Task {
                    await responseActor.setFailure(
                        error
                    )
                }
            },
            debug: config.debug
        )

        // let handler = RequestConnectionHandler(
        //     connection: conn,
        //     onSuccess: { response in
        //         log("Handler received success response: \(response.status.code)")
        //         Task {
        //             await responseActor.setSuccess(response)
        //         }
        //     },
        //     onError: { error in
        //         log("Handler received error: \(error)")
        //         Task {
        //             await responseActor.setFailure(error)
        //         }
        //     },
        //     debug: config.debug
        // )

        conn.stateUpdateHandler = { state in
            log("Connection state: \(state)")
            switch state {
            case .ready:
                log("Connection ready, handler sending request")
                handler.send(
                    wire
                )
            case .failed(let error):
                log("Connection failed: \(error.localizedDescription)")
                Task {
                    await responseActor.setFailure(.connectionFailed(error.localizedDescription))
                }
            case .cancelled:
                log("Connection cancelled")
            default:
                log("Connection state update: \(state)")
            }
        }

        log("Starting connection on queue")
        conn.start(queue: DispatchQueue(label: "http-client-\(UUID().uuidString)"))
        
        // Async timeout with polling
        log("Waiting for response (timeout: \(config.timeout)s)")
        let deadline = Date().addingTimeInterval(config.timeout)
        var pollCount = 0
        while await responseActor.getResult() == nil {
            pollCount += 1
            if Date() > deadline {
                log("Timeout after \(pollCount) polls")
                conn.cancel()
                throw ServerError.connectionFailed("Request timed out")
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        
        log("Got result after \(pollCount) polls")
        return try (await responseActor.getResult())!.get()
    }

    public func send<Input, Output>(
        _ endpoint: Endpoint<Input, Output>,
        headers: [String: String] = [:],
        body: String? = nil,
        auth: RequestAuth = .none
    ) async throws -> HTTPResponse {
        try await send(
            method: endpoint.method,
            path: endpoint.path,
            headers: headers,
            body: body,
            auth: auth
        )
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
