import Foundation
import TestFlows

@main
enum ServerSecurityFlowMain {
    static func main() async {
        do {
            if try await ServerProcessFixtureChild.runIfRequested(
                arguments: CommandLine.arguments
            ) {
                return
            }

            await TestFlowCLI.run(
                suite: ServerSecurityFlows.self,
                arguments: CommandLine.arguments
            )
        } catch {
            FileHandle.standardError.write(
                Data(
                    "server fixture child failed: \(error)\n".utf8
                )
            )

            Foundation.exit(1)
        }
    }
}
