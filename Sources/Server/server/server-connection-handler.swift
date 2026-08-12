import Foundation
import Network
import HTTP
import Loggers

final class ServerConnectionHandler: @unchecked Sendable {
    private enum ReadPhase: Sendable, Equatable {
        case idle
        case headers
        case content
    }

    private let connection: NWConnection
    private let router: Router
    private let config: ServerConfig
    private let statusRegistry: HTTPStatusRegistry
    private let queue: DispatchQueue

    private var buffer = Data()
    private var requestTail: Task<Void, Never>?

    private let activityCallback: HTTPActivityCallback?
    private let id: UUID
    private let onTermination: @Sendable (UUID) -> Void

    private var pendingOperations = 0
    private var readPhase: ReadPhase = .idle
    private var timeoutGeneration = 0
    private var timeoutTask: Task<Void, Never>?
    private var closing = false
    private var didTerminate = false
    
    init(
        id: UUID,
        connection: NWConnection,
        router: Router,
        config: ServerConfig,
        statusRegistry: HTTPStatusRegistry,
        onTermination: @escaping @Sendable (UUID) -> Void,
        activityCallback: HTTPActivityCallback? = nil
    ) {
        let queue = DispatchQueue(
            label: "server.connection.\(UUID().uuidString)"
        )

        self.id = id
        self.connection = connection
        self.router = router
        self.config = config
        self.statusRegistry = statusRegistry
        self.onTermination = onTermination
        self.activityCallback = activityCallback
        self.queue = queue

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else {
                return
            }

            switch state {
            case .ready:
                self.armIdleTimeoutIfPossible()

            case .failed(_),
                 .cancelled:
                self.finish()

            default:
                break
            }
        }

        connection.start(
            queue: queue
        )

        startReceiveLoop()
    }

    package func pendingOperationCount() async -> Int {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                continuation.resume(
                    returning: self?.pendingOperations ?? 0
                )
            }
        }
    }

    private func startReceiveLoop() {
        guard !closing,
              pendingOperations == 0
        else {
            return
        }
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65536
        ) { [weak self] data, _, isComplete, error in
            guard let self,
                  !self.closing
            else {
                return
            }

            if let error {
                self.log(
                    "Receive error: \(error)",
                    level: .error
                )

                self.connection.cancel()
                return
            }

            if let data,
               !data.isEmpty {
                if self.buffer.isEmpty,
                   self.readPhase == .idle {
                    self.beginHeadersIfNeeded()
                }

                self.buffer.append(
                    data
                )

                let marker = Data(
                    HTTPConstants.crlfCrLf.utf8
                )

                if self.buffer.range(
                    of: marker
                ) == nil,
                   self.buffer.count
                    > self.config.limits.headers.maximumHeaderBytes {
                    self.log(
                        "Header section exceeded maximum before terminator",
                        level: .debug
                    )

                    self.enqueueResponse(
                        HTTPResponse(
                            status: .requestHeaderFieldsTooLarge,
                            body: "Request Header Fields Too Large"
                        ),
                        closeAfterSend: true
                    )

                    return
                }

                guard self.processBuffer() else {
                    return
                }
            }

            if isComplete {
                self.closing = true

                self.cancelTimeout()

                self.enqueueRequest { [weak self] in
                    self?.connection.cancel()
                }

                return
            }

            self.startReceiveLoop()
        }
    }

    private func processBuffer() -> Bool {
        log(
            "processBuffer called, buffer size: \(buffer.count)",
            level: .debug
        )

        let marker = Data(
            HTTPConstants.crlfCrLf.utf8
        )

        while true {
            guard let range = buffer.range(
                of: marker
            ) else {
                log(
                    "HTTP terminator not found",
                    level: .debug
                )

                if !buffer.isEmpty {
                    beginHeadersIfNeeded()
                }

                return true
            }

            let headerEnd = range.upperBound

            guard headerEnd <= config.limits.headers.maximumHeaderBytes else {
                log(
                    "Header section too large: \(headerEnd)",
                    level: .debug
                )

                enqueueResponse(
                    HTTPResponse(
                        status: .requestHeaderFieldsTooLarge,
                        body: "Request Header Fields Too Large"
                    ),
                    closeAfterSend: true
                )

                return false
            }

            log(
                "Found HTTP terminator, headerEnd = \(headerEnd)",
                level: .debug
            )

            let headerData = buffer.subdata(
                in: 0..<headerEnd
            )

            let contentLength: Int

            do {
                contentLength = try HTTPFraming.extractContentLength(
                    from: headerData,
                    policy: config.limits.content
                ) ?? 0
            } catch HTTPParsingError.contentLengthTooLarge(
                let value,
                let maximumBytes
            ) {
                log(
                    "Request payload too large: Content-Length \(value), maximum \(maximumBytes)",
                    level: .debug
                )

                enqueueResponse(
                    HTTPResponse(
                        status: .payloadTooLarge,
                        body: "Payload Too Large"
                    ),
                    closeAfterSend: true
                )

                return false
            } catch {
                log(
                    "Invalid request Content-Length: \(error.localizedDescription)",
                    level: .debug
                )

                enqueueResponse(
                    HTTPResponse.badRequest(
                        body: "Invalid request Content-Length"
                    ),
                    closeAfterSend: true
                )

                return false
            }

            log(
                "Parsed Content-Length: \(contentLength)",
                level: .debug
            )

            guard contentLength <= Int.max - headerEnd else {
                log(
                    "Invalid request framing: headerEnd + Content-Length would overflow",
                    level: .debug
                )

                enqueueResponse(
                    HTTPResponse.badRequest(
                        body: "Invalid request framing"
                    ),
                    closeAfterSend: true
                )

                return false
            }

            let total =
                headerEnd + contentLength

            log(
                "Total needed: \(total), buffer has: \(buffer.count)",
                level: .debug
            )

            guard buffer.count >= total else {
                log(
                    "Buffer incomplete, waiting for more data",
                    level: .debug
                )

                beginContentIfNeeded()

                return true
            }

            let requestData = buffer.subdata(
                in: 0..<total
            )

            let requestText = String(
                data: requestData,
                encoding: .utf8
            ) ?? ""

            log(
                "Extracted complete request (\(requestText.count) chars)",
                level: .debug
            )

            buffer.removeSubrange(
                0..<total
            )

            handleText(
                requestText
            )

            guard !closing else {
                return false
            }

            finishReadPhase()

            return false
        }
    }

    private func activityPath(
        _ path: String
    ) -> String {
        guard let query = path.firstIndex(
            of: "?"
        ) else {
            return path
        }

        return String(
            path[..<query]
        )
    }

    private func enqueueRequest(
        _ operation: @escaping @Sendable () async -> Void
    ) {
        pendingOperations += 1

        if readPhase == .idle {
            cancelTimeout()
        }

        let previous =
            requestTail

        let next = Task { [previous, weak self] in
            if let previous {
                await previous.value
            }

            await operation()

            guard let self else {
                return
            }

            self.queue.async { [weak self] in
                self?.completeOperation()
            }
        }

        requestTail = next
    }

    private func enqueueResponse(
        _ response: HTTPResponse,
        closeAfterSend: Bool = false
    ) {
        if closeAfterSend {
            closing = true

            cancelTimeout()
        }

        enqueueRequest { [weak self] in
            guard let self else {
                return
            }

            await self.sendHTTPResponse(
                response,
                closeAfterSend: closeAfterSend
            )
        }
    }

    private func prepareToClose() async {
        await withCheckedContinuation {
            (
                continuation: CheckedContinuation<Void, Never>
            ) in

            queue.async { [weak self] in
                if let self {
                    self.closing = true
                    self.cancelTimeout()
                }

                continuation.resume()
            }
        }
    }

    private func handleText(
        _ text: String
    ) {
        log(
            "handleText called with \(text.count) bytes",
            level: .debug
        )

        do {
            let request = try HTTPRequestParser.parse(
                text,
                headerPolicy: config.limits.headers,
                requestTargetPolicy: config.security.target
            )

            let callback = activityCallback

            enqueueRequest { [request, callback, weak self] in
                guard let self else {
                    return
                }

                let startedAt =
                    Date()

                let execution =
                    await ServerRouteExecution.observe(
                        router: self.router,
                        request: request,
                        timeout: self.config.timeouts.execution
                    )

                let result: RouteResult
                let closeAfterSend: Bool

                switch execution {
                case .completed(
                    let completed
                ):
                    result = completed
                    closeAfterSend = false

                case .timedOut:
                    self.log(
                        "Route execution deadline reached",
                        level: .debug
                    )

                    result = RouteResult(
                        response: HTTPResponse(
                            status: .gatewayTimeout,
                            body: "Gateway Timeout"
                        ),
                        pattern: nil,
                        method: request.method,
                        synthetic: false
                    )

                    closeAfterSend = true

                    await self.prepareToClose()
                }

                let response =
                    result.response

                let finishedAt =
                    Date()

                if let callback {
                    let event = HTTPActivityEvent(
                        serviceName: self.config.name,
                        timestamp: finishedAt,
                        method: request.method,
                        path: self.activityPath(
                            request.path
                        ),
                        status: response.status,
                        clientDescription: String(
                            describing: self.connection.endpoint
                        ),
                        requestId: request.header(
                            "X-Request-Id"
                        ),
                        userAgent: request.header(
                            "User-Agent"
                        ),
                        duration: finishedAt.timeIntervalSince(
                            startedAt
                        ),
                        routePattern: result.pattern,
                        responseBytes: response.body.utf8.count,
                        failure: response.failure
                    )

                    callback(
                        event
                    )
                }

                await self.sendHTTPResponse(
                    response,
                    closeAfterSend: closeAfterSend
                )
            }
        } catch HTTPParsingError.headerSectionTooLarge(_),
                HTTPParsingError.headerLineTooLarge(_, _),
                HTTPParsingError.tooManyHeaders(_) {
            enqueueResponse(
                HTTPResponse(
                    status: .requestHeaderFieldsTooLarge,
                    body: "Request Header Fields Too Large"
                ),
                closeAfterSend: true
            )
        } catch HTTPParsingError.requestTargetTooLong(_) {
            enqueueResponse(
                HTTPResponse(
                    status: .uriTooLong,
                    body: "URI Too Long"
                ),
                closeAfterSend: true
            )
        } catch HTTPParsingError.ambiguousRequestTarget(_) {
            enqueueResponse(
                HTTPResponse.badRequest(
                    body: "Ambiguous request target"
                ),
                closeAfterSend: true
            )
        } catch HTTPParsingError.forbiddenHeader(let name) {
            log(
                "Forbidden request header rejected: \(name)",
                level: .debug
            )

            enqueueResponse(
                HTTPResponse.badRequest(
                    body: "Forbidden request header"
                ),
                closeAfterSend: true
            )
        } catch {
            log(
                "Invalid request rejected: \(error.localizedDescription)",
                level: .debug
            )

            enqueueResponse(
                HTTPResponse.badRequest(
                    body: "Invalid request"
                ),
                closeAfterSend: true
            )
        }
    }

    private func beginHeadersIfNeeded() {
        guard !closing,
              readPhase == .idle
        else {
            return
        }

        readPhase = .headers

        armTimeout(
            .headers,
            after: config.timeouts.headers
        )
    }

    private func beginContentIfNeeded() {
        guard !closing,
              readPhase != .content
        else {
            return
        }

        readPhase = .content

        armTimeout(
            .content,
            after: config.timeouts.content
        )
    }

    private func finishReadPhase() {
        readPhase = .idle

        cancelTimeout()
        armIdleTimeoutIfPossible()
    }

    private func completeOperation() {
        guard pendingOperations > 0 else {
            return
        }

        pendingOperations -= 1

        guard pendingOperations == 0 else {
            return
        }

        requestTail = nil

        guard !closing else {
            return
        }

        if !buffer.isEmpty {
            guard processBuffer() else {
                return
            }
        }

        armIdleTimeoutIfPossible()

        startReceiveLoop()
    }

    private func armIdleTimeoutIfPossible() {
        guard !closing,
              readPhase == .idle,
              buffer.isEmpty,
              pendingOperations == 0
        else {
            return
        }

        armTimeout(
            .idle,
            after: config.timeouts.idle
        )
    }

    private func armTimeout(
        _ phase: ReadPhase,
        after duration: Duration
    ) {
        cancelTimeout()

        timeoutGeneration &+= 1

        let generation =
            timeoutGeneration

        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(
                    for: duration
                )
            } catch {
                return
            }

            guard !Task.isCancelled,
                  let self
            else {
                return
            }

            self.queue.async { [weak self] in
                guard let self,
                      !self.closing,
                      self.timeoutGeneration == generation,
                      self.readPhase == phase
                else {
                    return
                }

                self.handleTimeout(
                    phase
                )
            }
        }
    }

    private func cancelTimeout() {
        timeoutGeneration &+= 1

        timeoutTask?.cancel()
        timeoutTask = nil
    }

    private func handleTimeout(
        _ phase: ReadPhase
    ) {
        guard !closing else {
            return
        }

        cancelTimeout()

        switch phase {
        case .idle:
            closing = true

            log(
                "Idle connection timeout reached",
                level: .debug
            )

            connection.cancel()

        case .headers:
            closing = true
            readPhase = .idle

            buffer.removeAll(
                keepingCapacity: false
            )

            log(
                "Request header timeout reached",
                level: .debug
            )

            enqueueResponse(
                HTTPResponse(
                    status: .requestTimeout,
                    body: "Request Timeout"
                ),
                closeAfterSend: true
            )

        case .content:
            closing = true
            readPhase = .idle

            buffer.removeAll(
                keepingCapacity: false
            )

            log(
                "Request content timeout reached",
                level: .debug
            )

            enqueueResponse(
                HTTPResponse(
                    status: .requestTimeout,
                    body: "Request Timeout"
                ),
                closeAfterSend: true
            )
        }
    }

    private func sendHTTPResponse(
        _ response: HTTPResponse,
        closeAfterSend: Bool = false
    ) async {
        let wire = HTTPResponseBuilder.build(
            response
        )

        log(
            "Sending HTTP response (\(wire.count) bytes)",
            level: .debug
        )

        let payload = Data(
            wire.utf8
        )

        await withCheckedContinuation {
            (
                continuation: CheckedContinuation<Void, Never>
            ) in

            connection.send(
                content: payload,
                completion: .contentProcessed { [weak self] error in
                    if let self {
                        if let error {
                            self.log(
                                "Send error: \(error)",
                                level: .error
                            )
                        } else {
                            self.log(
                                "Response sent successfully",
                                level: .debug
                            )
                        }

                        if closeAfterSend {
                            self.connection.cancel()
                        }
                    }

                    continuation.resume()
                }
            )
        }
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

    func cancel() {
        connection.cancel()
    }

    private func finish() {
        guard !didTerminate else {
            return
        }

        didTerminate = true
        closing = true

        cancelTimeout()

        onTermination(
            id
        )
    }
    
    private func log(_ msg: String, level: LogLevel) {
        if level.rawValue >= config.logLevel.rawValue {
            print("[\(connection.endpoint)] \(msg)")
        }
    }
}
