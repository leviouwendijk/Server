// import Foundation

// extension Array where Element == Route {
//     /// For every path that has at least one route, ensure there is an OPTIONS route.
//     /// The OPTIONS route inherits middleware from the first route at that path.
//     internal func appendingOptions() -> [Route] {
//         var result = self

//         let existingOptionsPaths = Set(
//             result
//                 .filter { $0.method == .options }
//                 .map { $0.path }
//         )

//         let groupedByPath = Dictionary(grouping: result, by: \.path)

//         for (path, routesAtPath) in groupedByPath {
//             // Skip if user already defined an explicit OPTIONS route
//             guard !existingOptionsPaths.contains(path) else { continue }
//             guard let template = routesAtPath.first else { continue }

//             var optionsRoute = Route(
//                 method: .options,
//                 path: path,
//                 handler: { _, _ in
//                     .noContent()
//                 }
//             )
//             // Inherit middleware for that path (cors, bearer, rate-limit, etc.)
//             optionsRoute.middleware = template.middleware
//             result.append(optionsRoute)
//         }

//         return result
//     }
// }
