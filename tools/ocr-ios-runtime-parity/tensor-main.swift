import Foundation
import CryptoKit

// No image metadata, oracle, model or reference tensors are accepted here.
@main struct NativeOCRTensorProbe {
    struct Input: Decodable {
        let index: Int
        let width: Int
        let height: Int
        let file: String
        let sha256: String
    }
    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { throw OCRTensorTransform.Failure.pixels }
        #if targetEnvironment(simulator)
        let environment = ProcessInfo.processInfo.environment
        guard let identity = environment["SIMULATOR_UDID"], UUID(uuidString: identity) != nil else {
            throw OCRTensorTransform.Failure.pixels
        }
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let runtime = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        let identityRecord: [String: Any] = ["udid": identity, "runtime": runtime,
            "simulatorCompileTarget": true, "pid": ProcessInfo.processInfo.processIdentifier]
        let identityJSON = try JSONSerialization.data(withJSONObject: identityRecord, options: .sortedKeys)
        print("ORT_IOS_IDENTITY " + String(decoding: identityJSON, as: UTF8.self))
        #else
        // The iPhone SDK build is a link check, not claimed physical execution.
        throw OCRTensorTransform.Failure.pixels
        #endif
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: root.appendingPathComponent("inputs.json")))
        guard inputs.count == 292 else { throw OCRTensorTransform.Failure.pixels }
        for (index, input) in inputs.enumerated() {
            guard index == input.index, input.file == "\(index).rgb" else { throw OCRTensorTransform.Failure.pixels }
            let url = root.appendingPathComponent(input.file)
            let bytes = try Data(contentsOf: url)
            guard hash(bytes) == input.sha256 else { throw OCRTensorTransform.Failure.pixels }
            let tensor = try OCRTensorTransform.make(rgb: Array(bytes), width: input.width, height: input.height)
            // Supported Apple architectures are little-endian; encode explicitly.
            var data = Data(capacity: tensor.values.count * 4)
            for value in tensor.values {
                var bits = value.bitPattern.littleEndian
                withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
            }
            try data.write(to: root.appendingPathComponent("\(index).native.f32"), options: .withoutOverwriting)
            let record: [String: Any] = ["index": index, "rgbSHA256": input.sha256,
                "tensorSHA256": hash(data), "validWidth": tensor.validWidth, "inputWidth": tensor.inputWidth]
            let json = try JSONSerialization.data(withJSONObject: record, options: .sortedKeys)
            print("ORT_IOS_TENSOR " + String(decoding: json, as: UTF8.self))
        }
    }
}
