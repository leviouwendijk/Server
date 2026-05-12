import TestFlows

@main
enum ServerSecurityFlowMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: ServerSecurityFlows.self,
            arguments: CommandLine.arguments
        )
    }
}
