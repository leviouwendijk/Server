// import Foundation
// import PklSwift
// import Structures

// public enum PKLEvalError: Error, LocalizedError {
//     case emptyBody
//     case invalidUTF8(json: String)
//     case invalidJSON(message: String)

//     public var errorDescription: String? {
//         switch self {
//         case .emptyBody:
//             return "Empty PKL body"
//         case .invalidUTF8(let json):
//             return "PKL output was not valid UTF-8: \(json.prefix(80))..."
//         case .invalidJSON(let message):
//             return "PKL JSON output could not be decoded: \(message)"
//         }
//     }
// }

// public func evaluatePklBody(_ body: String) async throws -> String {
//     let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
//     guard !trimmed.isEmpty else {
//         throw PKLEvalError.emptyBody
//     }

//     return try await PklSwift.withEvaluator { evaluator in
//         try await evaluator.evaluateOutputText(source: .text(trimmed))
//     }
// }

// /// Evaluate the synthetic module as JSON text using Pkl's own renderer,
// /// then decode that JSON into your JSONValue enum.
// public func evaluatePklJSONBody(_ body: String) async throws -> JSONValue {
//     let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
//     guard !trimmed.isEmpty else {
//         throw PKLEvalError.emptyBody
//     }

//     // Configure evaluator to render JSON (same idea as `pkl eval --format json`)
//     var options = PklSwift.EvaluatorOptions.preconfigured
//     options.outputFormat = "json"   // <- key line; `outputFormat` is a String? 

//     let jsonString = try await PklSwift.withEvaluator(options: options) { evaluator in
//         try await evaluator.evaluateOutputText(source: .text(trimmed))
//     }

//     guard let data = jsonString.data(using: .utf8) else {
//         throw PKLEvalError.invalidUTF8(json: jsonString)
//     }

//     do {
//         let decoder = JSONDecoder()
//         return try decoder.decode(JSONValue.self, from: data)
//     } catch {
//         throw PKLEvalError.invalidJSON(message: error.localizedDescription)
//     }
// }
