import Foundation

extension HTTPRequest {
    /// Best-effort client IP from common reverse-proxy headers.
    ///
    /// Notes:
    /// - Uses the FIRST IP in `X-Forwarded-For` (left-most), which is the original client in the standard chain.
    /// - Falls back to `X-Real-IP`.
    /// - Tries `Forwarded: for=...` as a last resort.
    /// - Returns the raw string (can be IPv4 or IPv6). No DNS. No port.
    public var clientIP: String? {
        // 1) X-Forwarded-For: "client, proxy1, proxy2"
        if let xff = header("X-Forwarded-For"),
           let first = xff.split(separator: ",", maxSplits: 1).first {
            let ip = first.trimmingCharacters(in: .whitespacesAndNewlines)
            if let cleaned = Self._cleanIPToken(ip) { return cleaned }
        }

        // 2) X-Real-IP: "client"
        if let xrip = header("X-Real-IP") {
            let ip = xrip.trimmingCharacters(in: .whitespacesAndNewlines)
            if let cleaned = Self._cleanIPToken(ip) { return cleaned }
        }

        // 3) Forwarded: for=1.2.3.4;proto=https;by=...
        // or for="[2001:db8::1]"
        if let fwd = header("Forwarded"),
           let ip = Self._parseForwardedFor(fwd),
           let cleaned = Self._cleanIPToken(ip) {
            return cleaned
        }

        return nil
    }

    /// Returns the full XFF chain (sanitized tokens), if present.
    public var clientIPChain: [String] {
        guard let xff = header("X-Forwarded-For") else { return [] }
        return xff
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap(Self._cleanIPToken)
    }

    private static func _parseForwardedFor(_ header: String) -> String? {
        // Very small parser: find first "for=" token
        // Examples:
        // Forwarded: for=192.0.2.60;proto=http;by=203.0.113.43
        // Forwarded: for="[2001:db8:cafe::17]";proto=https
        for part in header.split(separator: ",") { // multiple entries possible
            for kv in part.split(separator: ";") {
                let s = kv.trimmingCharacters(in: .whitespacesAndNewlines)
                if s.count >= 4, s.lowercased().hasPrefix("for=") {
                    let value = s.dropFirst(4)
                    return String(value).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }

    private static func _cleanIPToken(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }

        // remove optional quotes
        if s.first == "\"", s.last == "\"", s.count >= 2 {
            s = String(s.dropFirst().dropLast())
        }

        // IPv6 can be bracketed: [::1]
        if s.first == "[", let end = s.firstIndex(of: "]") {
            let inner = s[s.index(after: s.startIndex)..<end]
            return inner.isEmpty ? nil : String(inner)
        }

        // Sometimes "ip:port" shows up (not standard for XFF, but it happens)
        // Only strip ":port" for IPv4-ish tokens (single ':').
        let colonCount = s.reduce(0) { $0 + ($1 == ":" ? 1 : 0) }
        if colonCount == 1, let idx = s.firstIndex(of: ":") {
            let host = s[..<idx]
            return host.isEmpty ? nil : String(host)
        }

        return s
    }
}
