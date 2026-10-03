// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalLlama",
    products: [.library(name: "CLlamaRecovery", targets: ["CLlamaRecovery"])],
    targets: [.target(name: "CLlamaRecovery", publicHeadersPath: "include",
        linkerSettings: [.linkedLibrary("dl", .when(platforms: [.linux])),
                         .linkedLibrary("stdc++", .when(platforms: [.linux])),
                         .linkedLibrary("c++", .when(platforms: [.iOS, .macOS]))])],
    cxxLanguageStandard: .cxx17
)
