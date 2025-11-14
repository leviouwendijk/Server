import Foundation
import Network

final class ServerConnectionHandler: @unchecked Sendable {
    private let connection: NWConnection
    private let router: Router
    private let config: ServerConfig
    private let statusRegistry: HTTPStatusRegistry
    private var buffer = Data()
    
    init(
        connection: NWConnection,
        router: Router,
        config: ServerConfig,
        statusRegistry: HTTPStatusRegistry
    ) {
        self.connection = connection
        self.router = router
        self.config = config
        self.statusRegistry = statusRegistry
        startReceiveLoop()
    }
    
    private func startReceiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                self.log("Receive error: \(error)", level: .error)
                self.connection.cancel()
                return
            }
            
            if let data = data, !data.isEmpty {
                self.buffer.append(data)
                self.processBuffer()
            }
            
            if isComplete {
                self.connection.cancel()
                return
            }
            
            self.startReceiveLoop()
        }
    }
    
    private func processBuffer() {
        while let messageData = buffer.readLengthPrefixedMessage() {
            if let text = String(data: messageData, encoding: .utf8) {
                handleText(text)
            } else {
                log("Received binary data (\(messageData.count) bytes)", level: .debug)
            }
        }
    }
    
    private func handleText(_ text: String) {
        if text.hasPrefix("GET ") || text.hasPrefix("POST ") {
            do {
                let request = try HTTPRequestParser.parse(text)

                Task { [request] in
                    let response = await router.route(request)
                    self.sendHTTPResponse(response)
                }
                return
            } catch {
                let errorResp = HTTPResponse.badRequest(
                    body: "Invalid request: \(error.localizedDescription)"
                )
                sendHTTPResponse(errorResp)
                return
            }
        }

        let ack = "server-ack: received \(text.count) bytes"
        sendPlain(ack)
    }

    private func sendHTTPResponse(_ response: HTTPResponse) {
        let wire = HTTPResponseBuilder.build(response)
        log("Sending HTTP response (\(wire.count) bytes)", level: .debug)
        let payload = Data(wire.utf8)
        connection.send(
            content: payload,
            completion: .contentProcessed { [weak self] error in
                if let e = error {
                    self?.log("Send error: \(e)", level: .error)
                } else {
                    self?.log("Response sent successfully", level: .debug)
                }
            })
    }

    private func sendPlain(_ string: String) {
        log("Sending plain text (\(string.count) bytes)", level: .debug)
        let payload = Data(string.utf8)
        connection.send(
            content: payload,
            completion: .contentProcessed { [weak self] error in
                if let e = error {
                    self?.log("Send error: \(e)", level: .error)
                }
            })
    }

    // private func sendHTTPResponse(_ response: HTTPResponse) {
    //     let wire = HTTPResponseBuilder.build(response)
    //     sendPlain(wire)
    // }
    
    // private func sendPlain(_ string: String) {
    //     let payload = Data(string.utf8)
    //     let framed = Data.withLengthPrefix(payload)
    //     connection.send(content: framed, completion: .contentProcessed { error in
    //         if let e = error {
    //             self.log("Send error: \(e)", level: .error)
    //         }
    //     })
    // }
    
    private func log(_ msg: String, level: LogLevel) {
        if level.rawValue >= config.logLevel.rawValue {
            print("[\(connection.endpoint)] \(msg)")
        }
    }
}
