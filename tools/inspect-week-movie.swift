// Executed on the macOS host for the isolated two-gesture simulator recording.
import AVFoundation
import CoreVideo
import Foundation

struct Capture: Decodable {
    struct Geometry: Decodable { let x, y, width, height, left, right: Double }
    let travel, wallTime: Double
    let geometry: Geometry
    let reduced, systemReduced: Bool
    let samples: [[Double]]
}
struct Mark {
    let time, x, tone: Double
}
struct VideoError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

let movie = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
let documents = URL(fileURLWithPath: CommandLine.arguments[2])
let reduced = CommandLine.arguments[3] == "reduced"
let urls = try FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.hasPrefix("week-motion-") && $0.pathExtension == "json" }
let captures = try urls.map { try JSONDecoder().decode(Capture.self, from: Data(contentsOf: $0)) }
    .sorted { $0.wallTime < $1.wallTime }
guard captures.count == 2, Set(captures.map { $0.travel > 0 }).count == 2,
      let track = movie.tracks(withMediaType: .video).first else { throw VideoError("Missing both gesture records or video track") }

// The two color bands have opposite red/green components and share a high blue component.
// Average across each continuous stripe to tolerate video chroma subsampling.
func marks(in buffer: CVPixelBuffer, _ c: Capture, time: Double) -> [Mark] {
    let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
    let sx = Double(w) / c.geometry.width, sy = Double(h) / c.geometry.height
    let width = (c.travel > 0 ? 30.0 : 44.0) * sx
    let y1 = Int((c.geometry.y - 3) * sy), y2 = Int((c.geometry.y + 3) * sy)
    guard y1 >= 0, y2 < h, y1 < y2 else { return [] }
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let pixels = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self) else { return [] }
    let stride = CVPixelBufferGetBytesPerRow(buffer)
    let top = pixels.advanced(by: stride * y1), bottom = pixels.advanced(by: stride * y2)
    var result: [Mark] = [], count = 0, sum = 0
    for x in 0...w {
        if x < w {
            let i = 4 * x
            let (a, b, blueA) = (Int(top[i+2]), Int(top[i+1]), Int(top[i]))
            let (d, e, blueB) = (Int(bottom[i+2]), Int(bottom[i+1]), Int(bottom[i]))
            if min(blueA, blueB) > 165, blueA + blueB - min(a, b) - min(d, e) > 90,
               abs((a - b) + (d - e)) < 70, abs((a + b) - (d + e)) < 80 {
                sum += (a - b) - (d - e)
                count += 1
                continue
            }
        }
        if abs(Double(count) - width) <= max(4, width * 0.08),
           Double(x - count) / sx > c.geometry.left + 1, Double(x) / sx < c.geometry.right - 1 {
            result.append(Mark(time: time, x: (Double(x) - Double(count)/2) / sx,
                               tone: Double(sum) / (510 * Double(count))))
        }
        count = 0
        sum = 0
    }
    return result
}

func verify(_ c: Capture) throws -> ClosedRange<Double> {
    guard c.reduced == reduced, c.systemReduced == reduced else { throw VideoError("Native motion setting mismatch") }
    let reader = try AVAssetReader(asset: movie)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    output.alwaysCopiesSampleData = false
    reader.add(output)
    guard reader.startReading() else { throw reader.error ?? VideoError("Cannot decode recorded video") }
    var found: [Mark] = []
    while let sample = output.copyNextSampleBuffer() {
        if let buffer = CMSampleBufferGetImageBuffer(sample) {
            found += marks(in: buffer, c, time: CMSampleBufferGetPresentationTimeStamp(sample).seconds)
        }
    }
    guard reader.status == .completed else { throw reader.error ?? VideoError("Incomplete video decode") }
    print("WEEK_VIDEO geometry=\(c.geometry) duration=\(movie.duration.seconds) travel=\(c.travel) reduced=\(reduced) appFrames=\(c.samples) marks=\(found.map { [$0.time, $0.x, $0.tone] })")
    fflush(stdout)
    guard let earliest = found.first?.time, let latest = found.last?.time, latest - earliest <= 1.5 else {
        throw VideoError("A single brief marked transition was not identifiable")
    }
    if reduced {
        guard let first = found.first, let last = found.last,
              Set(found.map(\.time)).count >= 3,
              first.tone - last.tone > 0.30,
              found.allSatisfy({ abs($0.x - c.geometry.x) <= 2 }),
              Set(found.filter { abs($0.tone) < 0.96 }.map { Int(($0.tone * 20).rounded()) }).count >= 2 else {
            throw VideoError("Stationary intermediate crossfade pixels missing")
        }
    } else {
        let sign: Double = c.travel > 0 ? 1 : -1
        for page in [found.filter { $0.tone > 0.65 }, found.filter { $0.tone < -0.65 }] {
            guard let first = page.first, let last = page.last,
                  Set(page.map(\.time)).count >= 3,
                  page.contains(where: { ($0.x - last.x) * sign > 2 && (first.x - $0.x) * sign > 2 }),
                  (first.x - last.x) * sign > abs(c.travel) * 0.15 else {
                throw VideoError("Page did not slide through multiple encoded positions in the gesture direction")
            }
        }
        let expectedGap = c.travel - sign * 0.4 * (c.geometry.right - c.geometry.left)
        var paired = 0
        let frames = Dictionary(grouping: found, by: \.time)
        for frame in frames.values {
            if let a = frame.first(where: { $0.tone > 0.65 }), let b = frame.first(where: { $0.tone < -0.65 }) {
                paired += 1
                guard abs((b.x - a.x) - expectedGap) <= 3 else { throw VideoError("Rendered pages separated") }
            }
        }
        guard paired >= 2 else { throw VideoError("No sustained simultaneous page pair in the recording") }
    }
    return earliest...latest
}
var failed = false
var previousEnd: Double?
for capture in captures {
    do {
        let interval = try verify(capture)
        if let previousEnd, interval.lowerBound <= previousEnd {
            throw VideoError("The two uniquely marked gestures were not recorded in their original order")
        }
        previousEnd = interval.upperBound
    } catch {
        print("WEEK_VIDEO_ERROR travel=\(capture.travel) \(error.localizedDescription)")
        failed = true
    }
}
if failed { exit(1) }
