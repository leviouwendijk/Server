import Foundation
import Network

final class RequestConnectionHandler: @unchecked Sendable {
    private let connection: NWConnection
    private var buffer = Data()
    private let onSuccess: (HTTPResponse) -> Void
    private let onError: (ServerError) -> Void
    private var finished = false
    
    init(
        connection: NWConnection,
        onSuccess: @escaping (HTTPResponse) -> Void,
        onError: @escaping (ServerError) -> Void
    ) {
        self.connection = connection
        self.onSuccess = onSuccess
        self.onError = onError
        startReceiveLoop()
    }
    
    private func markDone() {
        guard !finished else { return }
        finished = true
    }
    
    private func startReceiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                if case .posix(let code) = error, code == .ECANCELED {
                    self.connection.cancel()
                    self.markDone()
                    return
                }
                self.onError(.connectionFailed(error.localizedDescription))
                self.markDone()
                return
            }
            
            if let data = data, !data.isEmpty {
                self.buffer.append(data)
                self.processBuffer()
            }
            
            if isComplete {
                self.connection.cancel()
                self.markDone()
                return
            }
            
            self.startReceiveLoop()
        }
    }
    
    private func processBuffer() {
        while let messageData = buffer.readLengthPrefixedMessage() {
            if let text = String(data: messageData, encoding: .utf8) {
                handleText(text)
            }
        }
    }
    
    private func handleText(_ text: String) {
        // Parse HTTP response
        if let response = parseHTTPResponse(text) {
            onSuccess(response)
        } else {
            onError(.responseEncodingFailed)
        }
        
        connection.cancel()
        markDone()
    }
    
    func send(_ string: String) {
        let payload = Data(string.utf8)
        let framed = Data.withLengthPrefix(payload)
        connection.send(content: framed, completion: .contentProcessed { _ in })
    }
}
