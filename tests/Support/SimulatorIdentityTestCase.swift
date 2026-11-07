import Foundation
import XCTest

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
