import Foundation

// Executed once inside the owned Simulator; accepts no expected identity input.
let process = ProcessInfo.processInfo
let os = process.operatingSystemVersion
#if targetEnvironment(simulator)
let simulatorTarget = true
#else
let simulatorTarget = false
#endif
let identity: [String: Any] = [
    "udid": process.environment["SIMULATOR_UDID"] ?? "",
    "runtime": "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
    "simulatorCompileTarget": simulatorTarget,
    "pid": process.processIdentifier
]
let data = try JSONSerialization.data(withJSONObject: identity, options: .sortedKeys)
print(String(decoding: data, as: UTF8.self))
