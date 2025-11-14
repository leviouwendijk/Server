import Foundation
import Network

final class RequestConnectionHandler: @unchecked Sendable {
    private let connection: NWConnection
    private var buffer = Data()
    private let onSuccess: (HTTPResponse) -> Void
    private let onError: (ServerError) -> Void
    private var finished = false
    private let debug: Bool
    
    init(
        connection: NWConnection,
        onSuccess: @escaping (HTTPResponse) -> Void,
        onError: @escaping (ServerError) -> Void,
        debug: Bool = false
    ) {
        self.connection = connection
        self.onSuccess = onSuccess
        self.onError = onError
        self.debug = debug
        log("Handler initialized")
    }
    
    private func log(_ msg: String) {
        guard debug else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] RequestConnectionHandler: \(msg)")
    }
    
    private func markDone() {
        guard !finished else { return }
        finished = true
        log("Marked done")
    }
    
    private func startReceiveLoop() {
        log("Starting receive loop")
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else {
                print("Handler deallocated during receive")
                return
            }
            
            self.log("Received data: \(data?.count ?? 0) bytes, isComplete: \(isComplete), error: \(error?.localizedDescription ?? "none")")
            
            if let error = error {
                if case .posix(let code) = error, code == .ECANCELED {
                    self.log("Receive cancelled")
                    self.connection.cancel()
                    self.markDone()
                    return
                }
                self.log("Receive error: \(error.localizedDescription)")
                self.onError(.connectionFailed(error.localizedDescription))
                self.markDone()
                return
            }
            
            if let data = data, !data.isEmpty {
                self.log("Appending \(data.count) bytes to buffer (total: \(self.buffer.count + data.count))")
                self.buffer.append(data)
                self.processBuffer()
            }
            
            if isComplete {
                self.log("Connection complete")
                self.connection.cancel()
                self.markDone()
                return
            }
            
            self.startReceiveLoop()
        }
    }
    
    private func processBuffer() {
        log("Processing buffer (\(buffer.count) bytes)")
        
        // Look for HTTP response terminator: \r\n\r\n
        let httpTerminator = Data("\r\n\r\n".utf8)
        
        guard let range = buffer.range(of: httpTerminator) else {
            log("HTTP terminator not found yet, waiting for more data")
            return
        }
        
        log("Found HTTP terminator at offset \(range.lowerBound)")
        
        // Extract complete response
        let responseEnd = range.upperBound
        let responseData = buffer.subdata(in: 0..<responseEnd)
        let responseText = String(data: responseData, encoding: .utf8) ?? ""
        
        log("Parsed response text (\(responseText.count) chars):\n\(responseText.prefix(200))")
        
        // Remove from buffer
        buffer.removeSubrange(0..<responseEnd)
        
        // Parse and handle
        do {
            log("Parsing HTTP response")
            let response = try HTTPResponseParser.parse(responseText)
            log("Successfully parsed response: \(response.status.code) \(response.status.reason)")
            onSuccess(response)
        } catch {
            log("Failed to parse response: \(error.localizedDescription)")
            onError(.responseEncodingFailed)
        }
        
        connection.cancel()
        markDone()
    }
    
    func send(_ string: String) {
        log("Sending request (\(string.count) bytes)")
        let payload = Data(string.utf8)
        connection.send(content: payload, completion: .contentProcessed { [weak self] error in
            guard let self = self else {
                print("Handler deallocated during send completion")
                return
            }
            
            if let error = error {
                self.log("Send error: \(error.localizedDescription)")
                self.onError(.connectionFailed(error.localizedDescription))
            } else {
                self.log("Send completed successfully, starting receive loop")
                self.startReceiveLoop()
            }
        })
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
