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
    private let peer: String
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
    private var draining = false
    private var didTerminate = false
    private var continueSent = false
    
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
        self.peer = Self.peerAddress(
            connection.endpoint
        )
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

    func pendingOperationCount() async -> Int {
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
                    > self.config.requestPolicies.headers.maximumHeaderBytes {
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

            guard headerEnd <= config.requestPolicies.headers.maximumHeaderBytes else {
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
                    policy: config.requestPolicies.content
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
                        status: .contentTooLarge,
                        body: "Content Too Large"
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

                sendContinueIfExpected(
                    headerData
                )

                beginContentIfNeeded()

                return true
            }

            let requestData = buffer.subdata(
                in: 0..<total
            )

            log(
                "Extracted complete request (\(requestData.count) bytes)",
                level: .debug
            )

            buffer.removeSubrange(
                0..<total
            )

            continueSent = false

            handleRequest(
                requestData
            )

            guard !closing else {
                return false
            }

            finishReadPhase()

            return false
        }
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

    /// Sends `100 Continue` once per request when the client waits for it before the body.
    /// Only called with no response in flight, so the interim response cannot interleave.
    private func sendContinueIfExpected(
        _ headerData: Data
    ) {
        guard !continueSent,
              !closing,
              Self.expectsContinue(
                headerData
              )
        else {
            return
        }

        continueSent = true

        connection.send(
            content: Data(
                "HTTP/1.1 100 Continue\r\n\r\n".utf8
            ),
            completion: .idempotent
        )
    }

    private static func expectsContinue(
        _ headerData: Data
    ) -> Bool {
        String(
            decoding: headerData,
            as: UTF8.self
        )
        .components(
            separatedBy: HTTPConstants.crlf
        )
        .dropFirst()
        .contains { line in
            guard let colon = line.firstIndex(
                of: ":"
            ) else {
                return false
            }

            return line[..<colon].lowercased() == "expect"
                && line[line.index(after: colon)...]
                    .trimmingCharacters(
                        in: .whitespaces
                    )
                    .lowercased() == "100-continue"
        }
    }

    private func handleRequest(
        _ data: Data
    ) {
        do {
            let request = try HTTPRequest(
                parsing: data,
                policies: config.requestPolicies
            )
            .resolvingClient(
                peer: peer,
                trustedProxies: config.trustedProxies
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
                    closeAfterSend = !request.keepAlive

                    if closeAfterSend {
                        await self.prepareToClose()
                    }

                case .timedOut:
                    self.log(
                        "Route execution deadline reached",
                        level: .debug
                    )

                    result = RouteResult(
                        response: HTTPResponse(
                            status: .serviceUnavailable,
                            body: "Service Unavailable"
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
                        path: request.path.raw,
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
                        responseBytes: response.bodyData.count,
                        failure: response.failure
                    )

                    callback(
                        event
                    )
                }

                let draining =
                    await self.isDraining()

                await self.sendHTTPResponse(
                    response,
                    closeAfterSend: closeAfterSend || draining,
                    method: request.method,
                    version: request.version,
                    keepAlive: request.keepAlive
                )
            }
        } catch {
            log(
                "Invalid request rejected: \(error.localizedDescription)",
                level: .debug
            )

            enqueueResponse(
                requestErrorResponse(
                    for: error
                ),
                closeAfterSend: true
            )
        }
    }

    private func requestErrorResponse(
        for error: Error
    ) -> HTTPResponse {
        if let validationError = error as? HTTPValidationError {
            switch validationError {
            case .unsupportedMethod:
                return HTTPResponse(
                    status: .notImplemented,
                    body: "Not Implemented"
                )

            case .unsupportedHTTPVersion:
                return HTTPResponse(
                    status: .httpVersionNotSupported,
                    body: "HTTP Version Not Supported"
                )

            case .requestTargetTooLong:
                return HTTPResponse(
                    status: .uriTooLong,
                    body: "URI Too Long"
                )

            case .contentLengthTooLarge,
                 .contentTooLarge:
                return HTTPResponse(
                    status: .contentTooLarge,
                    body: "Content Too Large"
                )

            default:
                return .badRequest(
                    body: "Bad Request"
                )
            }
        }

        if let parsingError = error as? HTTPParsingError {
            switch parsingError {
            case .headerSectionTooLarge,
                 .headerLineTooLarge,
                 .tooManyHeaders,
                 .chunkTrailerSectionTooLarge,
                 .tooManyChunkTrailers:
                return HTTPResponse(
                    status: .requestHeaderFieldsTooLarge,
                    body: "Request Header Fields Too Large"
                )

            case .contentLengthTooLarge,
                 .contentTooLarge:
                return HTTPResponse(
                    status: .contentTooLarge,
                    body: "Content Too Large"
                )

            default:
                return .badRequest(
                    body: "Bad Request"
                )
            }
        }

        return .badRequest(
            body: "Bad Request"
        )
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
            connection.cancel()
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
        closeAfterSend: Bool = false,
        method: HTTPMethod? = nil,
        version: String = HTTPConstants.httpVersion,
        keepAlive: Bool = true
    ) async {
        var response = response

        if closeAfterSend {
            response.headers.set(
                HTTPConstants.connectionHeader,
                "close"
            )
        } else if version == HTTPConstants.httpVersion10,
                  keepAlive {
            response.headers.set(
                HTTPConstants.connectionHeader,
                "keep-alive"
            )
        }

        let payload = HTTPResponseBuilder.buildData(
            response,
            for: method
        )

        log(
            "Sending HTTP response (\(payload.count) bytes)",
            level: .debug
        )

        let sendTimeout = config.timeouts.send

        await withCheckedContinuation {
            (
                continuation: CheckedContinuation<Void, Never>
            ) in

            let state = SendState()

            connection.send(
                content: payload,
                completion: .contentProcessed { [weak self] error in
                    guard !state.finished else {
                        return
                    }

                    state.finished = true

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

            queue.asyncAfter(
                deadline: .now() + Self.seconds(
                    sendTimeout
                )
            ) { [weak self] in
                guard !state.finished else {
                    return
                }

                state.finished = true

                if let self {
                    self.log(
                        "Send deadline reached; closing connection",
                        level: .debug
                    )

                    self.closing = true
                    self.cancelTimeout()
                    self.connection.cancel()
                }

                continuation.resume()
            }
        }
    }

    /// Mutated only on the connection queue (send completions and the deadline both run there).
    private final class SendState: @unchecked Sendable {
        var finished = false
    }

    private static func seconds(
        _ duration: Duration
    ) -> Double {
        let components = duration.components

        return Double(
            components.seconds
        ) + Double(
            components.attoseconds
        ) / 1e18
    }

    private static func peerAddress(
        _ endpoint: NWEndpoint
    ) -> String {
        guard case .hostPort(let host, _) = endpoint else {
            return "\(endpoint)"
        }

        switch host {
        case .ipv4(let address):
            return "\(address)"

        case .ipv6(let address):
            return "\(address)"

        case .name(let name, _):
            return name

        @unknown default:
            return "\(host)"
        }
    }

    /// Graceful stop: an idle connection closes now; a busy one finishes its current
    /// response, sent with `Connection: close`, and then closes.
    func closeWhenIdle() {
        queue.async { [weak self] in
            guard let self else {
                return
            }

            self.draining = true
            self.closing = true
            self.cancelTimeout()

            if self.pendingOperations == 0 {
                self.connection.cancel()
            }
        }
    }

    private func isDraining() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                continuation.resume(
                    returning: self?.draining ?? true
                )
            }
        }
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
    
    private func log(
        _ message: @autoclosure () -> String,
        level: LogLevel
    ) {
        guard level.rawValue >= config.logLevel.rawValue else {
            return
        }

        print(
            "[\(connection.endpoint)] \(message())"
        )
    }
}
