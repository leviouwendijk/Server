import Foundation

// public func group(
//     _ prefix: String...,
//     @GroupBuilder builder: () -> [Route]
// ) -> [Route] {
//     let prefixPath = prefix.joined(separator: "/")
    
//     return builder().map { route in
//         let newPath: String
//         if route.path == "/" {
//             newPath = "/" + prefixPath
//         } else {
//             newPath = "/" + prefixPath + route.path
//         }

//         var newRoute = Route(
//             method: route.method,
//             path: newPath,
//             handler: route.handler
//         )
//         newRoute.middleware       = route.middleware
//         newRoute.syntheticMethods = route.syntheticMethods
//         return newRoute
//     }
// }

public func group(
    _ prefix: String...,
    @GroupBuilder builder: () -> [Route]
) -> GroupWithMiddleware {
    let prefixPath = prefix.joined(separator: "/")
    
    let routes = builder().map { route in
        let newPath: String
        if route.path == "/" {
            newPath = "/" + prefixPath
        } else {
            newPath = "/" + prefixPath + route.path
        }

        var newRoute = Route(
            method: route.method,
            path: newPath,
            handler: route.handler
        )
        newRoute.middleware       = route.middleware
        newRoute.syntheticMethods = route.syntheticMethods
        return newRoute
    }

    return GroupWithMiddleware(routes: routes)
}
