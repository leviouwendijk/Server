import Foundation

extension Data {
    public mutating func readLengthPrefixedMessage() -> Data? {
        guard self.count >= 4 else { return nil }

        let start = self.startIndex
        var length: UInt32 = 0
        for i in 0..<4 {
            let idx = self.index(start, offsetBy: i)
            length = (length << 8) | UInt32(self[idx])
        }

        let total = 4 + Int(length)
        guard self.count >= total else {
            // not enough data yet
            return nil
        }

        // drop length prefix
        self.removeFirst(4)

        let payloadSlice = self.prefix(Int(length))
        self.removeFirst(Int(length))
        return Data(payloadSlice)
    }

    public static func withLengthPrefix(_ payload: Data) -> Data {
        var d = Data()
        let len = UInt32(payload.count)
        let bytes: [UInt8] = [
            UInt8((len >> 24) & 0xff),
            UInt8((len >> 16) & 0xff),
            UInt8((len >> 8) & 0xff),
            UInt8(len & 0xff)
        ]
        d.append(contentsOf: bytes)
        d.append(payload)
        return d
    }
}
