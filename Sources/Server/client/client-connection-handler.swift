import Foundation
import HTTP
import Network

final class RequestConnectionHandler: @unchecked Sendable {
    private let connection: NWConnection
    private let requestMethod: HTTPMethod
    private let policies: HTTPResponsePolicies
    private let onSuccess: (HTTPResponse) -> Void
    private let onError: (ServerError) -> Void
    private let debug: Bool

    private var buffer = Data()
    private var responseHead: HTTPResponse?
    private var framing: HTTPFraming.Body?
    private var chunkedDecoder: HTTPChunkedBody.Decoder?
    private var finished = false

    init(
        connection: NWConnection,
        requestMethod: HTTPMethod,
        policies: HTTPResponsePolicies = HTTPPolicies.response.default,
        onSuccess: @escaping (HTTPResponse) -> Void,
        onError: @escaping (ServerError) -> Void,
        debug: Bool = false
    ) {
        self.connection = connection
        self.requestMethod = requestMethod
        self.policies = policies
        self.onSuccess = onSuccess
        self.onError = onError
        self.debug = debug

        log(
            "Handler initialized"
        )
    }

    private func log(
        _ message: String
    ) {
        guard debug else {
            return
        }

        let timestamp = ISO8601DateFormatter()
            .string(
                from: Date()
            )

        print(
            "[\(timestamp)] RequestConnectionHandler: \(message)"
        )
    }

    private func markDone() {
        guard !finished else {
            return
        }

        finished = true

        log(
            "Marked done"
        )
    }

    private func failResponse(
        _ message: String
    ) {
        guard !finished else {
            return
        }

        log(
            message
        )

        connection.cancel()

        onError(
            .responseEncodingFailed
        )

        markDone()
    }

    private func validateHeaderBufferLimit() -> Bool {
        let marker = Data(
            HTTPConstants.crlfCrLf.utf8
        )

        let maximum =
            policies.headers.maximumHeaderBytes

        if let range = buffer.range(
            of: marker
        ) {
            guard range.lowerBound <= maximum else {
                failResponse(
                    "Response header exceeded configured maximum"
                )

                return false
            }

            return true
        }

        let bufferedMaximum =
            maximum + marker.count - 1

        guard buffer.count <= bufferedMaximum else {
            failResponse(
                "Unterminated response header exceeded configured maximum"
            )

            return false
        }

        return true
    }

    private func startReceiveLoop() {
        guard !finished else {
            return
        }

        log(
            "Starting receive loop"
        )

        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65536
        ) { [weak self] data, _, isComplete, error in
            guard let self else {
                return
            }

            guard !self.finished else {
                return
            }

            self.log(
                "Received data: \(data?.count ?? 0) bytes, "
                    + "isComplete: \(isComplete), "
                    + "error: \(error?.localizedDescription ?? "none")"
            )

            if let error {
                if case .posix(let code) = error,
                   code == .ECANCELED {
                    self.log(
                        "Receive cancelled"
                    )

                    self.connection.cancel()
                    self.markDone()

                    return
                }

                self.log(
                    "Receive error: \(error.localizedDescription)"
                )

                self.onError(
                    .connectionFailed(
                        error.localizedDescription
                    )
                )

                self.markDone()

                return
            }

            if let data,
               !data.isEmpty {
                self.log(
                    "Appending \(data.count) bytes to buffer "
                        + "(total: \(self.buffer.count + data.count))"
                )

                self.buffer.append(
                    data
                )

                if self.responseHead == nil,
                   !self.validateHeaderBufferLimit() {
                    return
                }
            }

            self.processBuffer(
                isComplete: isComplete
            )

            guard !self.finished else {
                return
            }

            if isComplete {
                self.failResponse(
                    "Connection completed before HTTP response framing completed"
                )

                return
            }

            self.startReceiveLoop()
        }
    }

    private func processBuffer(
        isComplete: Bool
    ) {
        guard !finished else {
            return
        }

        if responseHead == nil {
            guard parseResponseHeadIfAvailable() else {
                return
            }

            guard !finished else {
                return
            }
        }

        guard let responseHead,
              let framing
        else {
            return
        }

        switch framing {
        case .none:
            finishResponse(
                head: responseHead,
                body: Data(),
                trailers: HTTPHeaders()
            )

        case .contentLength(let contentLength):
            guard contentLength >= 0,
                  contentLength <= policies.content.maximumBytes
            else {
                failResponse(
                    "Content-Length exceeds configured content policy"
                )

                return
            }

            guard buffer.count >= contentLength else {
                return
            }

            let bodyEnd = buffer.index(
                buffer.startIndex,
                offsetBy: contentLength
            )

            let body = buffer.subdata(
                in: buffer.startIndex..<bodyEnd
            )

            finishResponse(
                head: responseHead,
                body: body,
                trailers: HTTPHeaders()
            )

        case .chunked:
            guard var decoder = chunkedDecoder else {
                failResponse(
                    "Chunked response decoder is unavailable"
                )

                return
            }

            let incoming = buffer

            buffer.removeAll(
                keepingCapacity: true
            )

            do {
                let progress = try decoder.receive(
                    incoming
                )

                chunkedDecoder = decoder

                switch progress {
                case .incomplete:
                    if isComplete {
                        failResponse(
                            "Connection completed before chunked body terminated"
                        )
                    }

                case .complete(let output):
                    finishResponse(
                        head: responseHead,
                        body: output.body,
                        trailers: output.trailers
                    )
                }
            } catch {
                failResponse(
                    "Invalid chunked response body: "
                        + error.localizedDescription
                )
            }

        case .closeDelimited:
            guard buffer.count <= policies.content.maximumBytes else {
                failResponse(
                    "Close-delimited response exceeds configured content policy"
                )

                return
            }

            guard isComplete else {
                return
            }

            finishResponse(
                head: responseHead,
                body: buffer,
                trailers: HTTPHeaders()
            )

        case .tunnel:
            failResponse(
                "Successful CONNECT establishes a tunnel, "
                    + "which HTTPClient.send cannot represent as HTTPResponse"
            )
        }
    }

    private func parseResponseHeadIfAvailable() -> Bool {
        let terminator = Data(
            HTTPConstants.crlfCrLf.utf8
        )

        guard let range = buffer.range(
            of: terminator
        ) else {
            log(
                "HTTP header terminator not found, waiting for more data"
            )

            return false
        }

        let headerEnd =
            range.upperBound

        let headerData = buffer.subdata(
            in: buffer.startIndex..<headerEnd
        )

        guard let headerText = String(
            data: headerData,
            encoding: .utf8
        ) else {
            failResponse(
                "HTTP response head is not valid UTF-8"
            )

            return false
        }

        do {
            let head = try HTTPResponse(
                parsing: headerText,
                policies: policies
            )

            let bodyFraming = try HTTPFraming.responseBody(
                requestMethod: requestMethod,
                status: head.status,
                headers: head.headers
            )

            responseHead = head
            framing = bodyFraming

            buffer.removeSubrange(
                buffer.startIndex..<headerEnd
            )

            if case .chunked = bodyFraming {
                chunkedDecoder = HTTPChunkedBody.Decoder(
                    maximumDecodedBytes:
                        policies.content.maximumBytes,
                    trailerPolicy:
                        policies.headers
                )
            }

            log(
                "Parsed response head: "
                    + "status \(head.status.code), "
                    + "framing \(bodyFraming)"
            )

            return true
        } catch {
            failResponse(
                "Invalid HTTP response head/framing: "
                    + error.localizedDescription
            )

            return false
        }
    }

    private func finishResponse(
        head: HTTPResponse,
        body: Data,
        trailers: HTTPHeaders
    ) {
        guard !finished else {
            return
        }

        guard body.count <= policies.content.maximumBytes else {
            failResponse(
                "Decoded response body exceeds configured content policy"
            )

            return
        }

        guard let bodyText = String(
            data: body,
            encoding: .utf8
        ) else {
            failResponse(
                "HTTP response body is not valid UTF-8"
            )

            return
        }

        let response = HTTPResponse(
            status: head.status,
            headers: head.headers,
            body: bodyText,
            trailers: trailers,
            failure: head.failure
        )

        log(
            "Completed response: "
                + "status \(response.status.code), "
                + "body bytes \(body.count), "
                + "trailers \(trailers.count)"
        )

        onSuccess(
            response
        )

        connection.cancel()

        markDone()
    }

    func send(
        _ string: String
    ) {
        log(
            "Sending request (\(string.utf8.count) bytes)"
        )

        let payload = Data(
            string.utf8
        )

        connection.send(
            content: payload,
            completion: .contentProcessed { [weak self] error in
                guard let self else {
                    return
                }

                if let error {
                    self.log(
                        "Send error: \(error.localizedDescription)"
                    )

                    self.onError(
                        .connectionFailed(
                            error.localizedDescription
                        )
                    )

                    self.markDone()

                    return
                }

                self.log(
                    "Send completed successfully, starting receive loop"
                )

                self.startReceiveLoop()
            }
        )
    }
}

// final class RequestConnectionHandler: @unchecked Sendable {
//     private let connection: NWConnection
//     private var buffer = Data()
//     private let onSuccess: (HTTPResponse) -> Void
//     private let onError: (ServerError) -> Void
//     private var finished = false
    
//     init(
//         connection: NWConnection,
//         onSuccess: @escaping (HTTPResponse) -> Void,
//         onError: @escaping (ServerError) -> Void
//     ) {
//         self.connection = connection
//         self.onSuccess = onSuccess
//         self.onError = onError
//         startReceiveLoop()
//     }
    
//     private func markDone() {
//         guard !finished else { return }
//         finished = true
//     }
    
//     private func startReceiveLoop() {
//         connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
//             guard let self = self else { return }
            
//             if let error = error {
//                 if case .posix(let code) = error, code == .ECANCELED {
//                     self.connection.cancel()
//                     self.markDone()
//                     return
//                 }
//                 self.onError(.connectionFailed(error.localizedDescription))
//                 self.markDone()
//                 return
//             }
            
//             if let data = data, !data.isEmpty {
//                 self.buffer.append(data)
//                 self.processBuffer()
//             }
            
//             if isComplete {
//                 self.connection.cancel()
//                 self.markDone()
//                 return
//             }
            
//             self.startReceiveLoop()
//         }
//     }
    
//     private func processBuffer() {
//         while let messageData = buffer.readLengthPrefixedMessage() {
//             if let text = String(data: messageData, encoding: .utf8) {
//                 handleText(text)
//             }
//         }
//     }
    
//     private func handleText(_ text: String) {
//         // Parse HTTP response
//         if let response = parseHTTPResponse(text) {
//             onSuccess(response)
//         } else {
//             onError(.responseEncodingFailed)
//         }
        
//         connection.cancel()
//         markDone()
//     }
    
//     func send(_ string: String) {
//         let payload = Data(string.utf8)
//         let framed = Data.withLengthPrefix(payload)
//         connection.send(content: framed, completion: .contentProcessed { _ in })
//     }
// }
