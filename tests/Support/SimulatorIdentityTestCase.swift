import Foundation
import XCTest

func simulatorExecutionIdentity(caseName: String) throws -> String {
    let process = ProcessInfo.processInfo
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
    return String(decoding: data, as: UTF8.self)
}

class SimulatorIdentityTestCase: XCTestCase {
    private enum IdentityFailure: Error { case notSimulator }
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        // Actual Runner identity, once per case; no expected values are inputs.
        print("TAKUPOKE_UI_EXECUTION_IDENTITY " + (try simulatorExecutionIdentity(caseName: name)))
        #if !targetEnvironment(simulator)
        throw IdentityFailure.notSimulator
        #endif
    }
}
