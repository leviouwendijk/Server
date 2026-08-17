import Foundation
import Path

// public func group(
//     _ prefix: String...,
//     @GroupBuilder builder: () -> [Route]
// ) -> GroupWithMiddleware {
//     let prefixPath = prefix.joined(separator: "/")
    
//     let routes = builder().map { route in
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

//     return GroupWithMiddleware(routes: routes)
// }

public func group(
    _ prefix: String...,
    @GroupBuilder builder: () -> [Route]
) -> GroupWithMiddleware {
    let prefixPath = prefix.joined(separator: "/")
    
    let routes = builder().map { route in
        let newPath: String
        if route.path.raw == "/" {
            newPath = "/" + prefixPath
        } else {
            newPath = "/" + prefixPath + route.path.raw
        }

        var newRoute = Route(
            method: route.method,
            path: newPath,
            handler: route.handler
        )
        newRoute.middleware       = route.middleware
        newRoute.jsonPolicy       = route.jsonPolicy
        newRoute.syntheticMethods = route.syntheticMethods
        return newRoute
    }

    return GroupWithMiddleware(routes: routes)
}

public func group(
    _ prefix: StandardPath,
    @GroupBuilder builder: () -> [Route]
) -> GroupWithMiddleware {
    let routes = builder().map { route in
        let newPath = prefix.merged(
            appending: StandardPath(
                rawPath: route.path.raw
            )
        )

        var newRoute = Route(
            method: route.method,
            path: newPath,
            handler: route.handler
        )
        newRoute.middleware       = route.middleware
        newRoute.jsonPolicy       = route.jsonPolicy
        newRoute.syntheticMethods = route.syntheticMethods
        return newRoute
    }

    return GroupWithMiddleware(routes: routes)
}
