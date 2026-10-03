// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "CoreAIRecoveryRuntime",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [.library(name: "CoreAIRecoveryRuntime", type: .dynamic, targets: ["CoreAIRecoveryRuntime"])],
    dependencies: [.package(url: "https://github.com/apple/coreai-models", revision: "52c84ba874b2c57adcede08a671ce96ed1b3f433")],
    targets: [.target(name: "CoreAIRecoveryRuntime", dependencies: [.product(name: "CoreAILM", package: "coreai-models")])]
)
