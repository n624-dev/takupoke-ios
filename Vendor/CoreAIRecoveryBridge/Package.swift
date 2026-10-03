// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CoreAIRecoveryBridge", platforms: [.iOS("26.0"), .macOS(.v13)],
    products: [.library(name: "CCoreAIRecovery", targets: ["CCoreAIRecovery"])],
    targets: [.target(name: "CCoreAIRecovery", publicHeadersPath: "include", cSettings: [.unsafeFlags(["-fobjc-arc"])], linkerSettings: [.linkedFramework("Foundation")])])
