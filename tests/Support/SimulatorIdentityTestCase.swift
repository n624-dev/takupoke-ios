import Foundation
import XCTest
#if targetEnvironment(simulator) && canImport(UIKit)
import CryptoKit
import UIKit
#endif

private enum SimulatorIdentityFailure: Error { case notSimulator, timedOut, invalidCaseName }

func simulatorExecutionCaseName(caseName: String, testClass: XCTestCase.Type) throws -> String {
    // XCTestCase.name omits the Swift module; its completion log includes it.
    // Derive that module from the actual executing type, never an expected input.
    let prefix = "-[" + String(describing: testClass) + " "
    guard caseName.hasPrefix(prefix), caseName.hasSuffix("]") else {
        throw SimulatorIdentityFailure.invalidCaseName
    }
    return "-[" + String(reflecting: testClass) + " " + caseName.dropFirst(prefix.count)
}

func simulatorExecutionIdentity(caseName: String) throws -> String {
    let process = ProcessInfo.processInfo
    let started = process.systemUptime
    let os = process.operatingSystemVersion
    #if targetEnvironment(simulator)
    let simulatorTarget = true
    #else
    let simulatorTarget = false
    #endif
    let record: [String: Any] = [
        "case": caseName,
        "udid": process.environment["SIMULATOR_UDID"] ?? "",
        "runtime": String(os.majorVersion) + "." + String(os.minorVersion) + "." + String(os.patchVersion),
        "simulatorCompileTarget": simulatorTarget,
        "pid": process.processIdentifier
    ]
    let data = try JSONSerialization.data(withJSONObject: record, options: .sortedKeys)
    let text = String(decoding: data, as: UTF8.self)
    let elapsed = process.systemUptime - started
    guard elapsed.isFinite, elapsed >= 0, elapsed <= 45 else { throw SimulatorIdentityFailure.timedOut }
    return text
}

class SimulatorIdentityTestCase: XCTestCase {
    #if targetEnvironment(simulator) && canImport(UIKit)
    @MainActor private static var attemptedFailureScreenshot = false

    override func record(_ issue: XCTIssue) {
        if issue.isFailure && Thread.isMainThread {
            MainActor.assumeIsolated { Self.recordFailureScreenshot() }
        }
        super.record(issue)
    }

    @MainActor
    private static func recordFailureScreenshot() {
        guard !attemptedFailureScreenshot else { return }
        attemptedFailureScreenshot = true
        let screenshot = XCUIScreen.main.screenshot().image
        let size = screenshot.size
        guard size.width > 0, size.height > 0 else { return }
        let limit: CGFloat = 1024
        let scale = min(1, limit / max(size.width, size.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let bounds = CGRect(x: 0, y: 0, width: min(limit, (size.width * scale).rounded(.up)),
                            height: min(limit, (size.height * scale).rounded(.up)))
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        let image = renderer.pngData { _ in screenshot.draw(in: bounds) }
        guard !image.isEmpty, image.count <= 2 * 1024 * 1024 else { return }
        let hash = SHA256.hash(data: image).map { String(format: "%02x", $0) }.joined()
        let encoded = Array(image.base64EncodedString())
        let chunkSize = 6000
        let name = "simulator-failure"
        print("TAKUPOKE_UI_IMAGE BEGIN \(name) \(hash) \(image.count)")
        for offset in stride(from: 0, to: encoded.count, by: chunkSize) {
            let chunk = String(encoded[offset..<min(offset + chunkSize, encoded.count)])
            print("TAKUPOKE_UI_IMAGE DATA \(name) \(offset / chunkSize) \(chunk)")
        }
        print("TAKUPOKE_UI_IMAGE END \(name) \((encoded.count + chunkSize - 1) / chunkSize)")
        print("TAKUPOKE_SIMULATOR_FAILURE_SCREEN source=xctest")
    }
    #endif

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        // Actual Runner identity, once per case; no expected values are inputs.
        let actualCase = try simulatorExecutionCaseName(caseName: name, testClass: type(of: self))
        print("TAKUPOKE_UI_EXECUTION_IDENTITY " + (try simulatorExecutionIdentity(caseName: actualCase)))
        #if !targetEnvironment(simulator)
        throw SimulatorIdentityFailure.notSimulator
        #endif
    }
}

#if canImport(UIKit)
extension SimulatorIdentityTestCase {
    func snapshotNodes(in root: any XCUIElementSnapshot) -> [any XCUIElementSnapshot]? {
        var pending: [any XCUIElementSnapshot] = [root]
        var nodes: [any XCUIElementSnapshot] = []
        while let node = pending.popLast() {
            guard nodes.count < 4096 else { return nil }
            nodes.append(node)
            pending.append(contentsOf: node.children.reversed())
        }
        return nodes
    }
}
#endif
