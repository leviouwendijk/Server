import Foundation

// Simple PKL-ish "key = value" parser with optional nested blocks.
public func parseSimplePKL(_ body: String) -> [String: String] {
    var result: [String: String] = [:]
    var scopes: [String] = []

    for rawLine in body.split(whereSeparator: \.isNewline) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty { continue }
        if line.hasPrefix("#") || line.hasPrefix("//") {
            continue
        }

        if line.hasSuffix("{") {
            let namePart = line.dropLast().trimmingCharacters(in: .whitespaces)
            if !namePart.isEmpty {
                scopes.append(namePart)
            }
            continue
        }

        if line == "}" {
            if !scopes.isEmpty { scopes.removeLast() }
            continue
        }

        guard let eqIndex = line.firstIndex(of: "=") else {
            continue
        }

        let key = String(line[..<eqIndex]).trimmingCharacters(in: .whitespaces)
        var value = String(line[line.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)

        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value = String(value[value.index(after: value.startIndex)..<value.index(before: value.endIndex)])
        }

        let fullKey: String
        if scopes.isEmpty {
            fullKey = key
        } else {
            fullKey = (scopes + [key]).joined(separator: ".")
        }

        result[fullKey] = value
    }

    return result
}
