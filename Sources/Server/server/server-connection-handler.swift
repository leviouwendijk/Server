import Foundation
import Network
import plate

final class ServerConnectionHandler: @unchecked Sendable {
    private let connection: NWConnection
    private let router: Router
    private let config: ServerConfig
    private let statusRegistry: HTTPStatusRegistry
    private var buffer = Data()
    private let activityCallback: HTTPActivityCallback?
    
    init(
        connection: NWConnection,
        router: Router,
        config: ServerConfig,
        statusRegistry: HTTPStatusRegistry,
        activityCallback: HTTPActivityCallback? = nil
    ) {
        self.connection = connection
        self.router = router
        self.config = config
        self.statusRegistry = statusRegistry
        self.activityCallback = activityCallback

        connection.start(queue: DispatchQueue(label: "server.connection.\(UUID().uuidString)"))
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
    
    // private func processBuffer() {
    //     while let messageData = buffer.readLengthPrefixedMessage() {
    //         if let text = String(data: messageData, encoding: .utf8) {
    //             handleText(text)
    //         } else {
    //             log("Received binary data (\(messageData.count) bytes)", level: .debug)
    //         }
    //     }
    // }

    private func processBuffer() {
        log("processBuffer called, buffer size: \(buffer.count)", level: .debug)

        let httpTerminator = Data("\r\n\r\n".utf8)

        guard let range = buffer.range(of: httpTerminator) else {
            log("HTTP terminator not found", level: .debug)
            return
        }

        let headerEnd = range.upperBound
        log("Found HTTP terminator, headerEnd = \(headerEnd)", level: .debug)

        let headerData = buffer.subdata(in: 0..<headerEnd)
        let contentLength = HTTPRequestParser.extractContentLength(from: headerData) ?? 0
        log("Parsed Content-Length: \(contentLength)", level: .debug)

        let totalNeeded = headerEnd + contentLength
        log("Total needed: \(totalNeeded), buffer has: \(buffer.count)", level: .debug)

        guard buffer.count >= totalNeeded else {
            log("Buffer incomplete, waiting for more data", level: .debug)
            return
        }

        let requestData = buffer.subdata(in: 0..<totalNeeded)
        let requestText = String(data: requestData, encoding: .utf8) ?? ""
        log("Extracted complete request (\(requestText.count) chars)", level: .debug)

        buffer.removeSubrange(0..<totalNeeded)

        handleText(requestText)
    }

    private func handleText(_ text: String) {
        log("handleText called with \(text.count) bytes", level: .debug)
        log("Request text: \(text.prefix(100))", level: .debug)

        // if text.hasPrefix("GET ") || text.hasPrefix("POST ") {
            do {
                let request = try HTTPRequestParser.parse(text)

                // let endpointDescription = String(describing: connection.endpoint)
                let callback = self.activityCallback

                // Task { [request] in
                //     let response = await router.route(request)
                //     self.sendHTTPResponse(response)
                // }
                // return
                Task { [request, callback, weak self] in
                    guard let self else { return }
                    let startedAt = Date()
                    let response = await self.router.route(request)
                    let finishedAt = Date()

                    if let cb = callback {
                        let event = HTTPActivityEvent(
                            serviceName: config.name,
                            timestamp: finishedAt,
                            method: request.method,
                            path: request.path,
                            status: response.status,
                            clientDescription: String(describing: connection.endpoint),
                            requestId: request.header("X-Request-Id"),
                            userAgent: request.header("User-Agent"),
                            duration: finishedAt.timeIntervalSince(startedAt)
                        )
                        cb(event)
                    }

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
        // }

        // let ack = "server-ack: received \(text.count) bytes"
        // sendPlain(ack)
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
