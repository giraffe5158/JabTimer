import Foundation
import AVFoundation
import Vision

// ---- helpers ----
func angleAtB(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
    let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
    let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
    let dot = v1.dx * v2.dx + v1.dy * v2.dy
    let m1 = hypot(v1.dx, v1.dy), m2 = hypot(v2.dx, v2.dy)
    guard m1 > 0, m2 > 0 else { return .nan }
    let cosTheta = max(-1, min(1, dot / (m1*m2)))
    return acos(cosTheta) * 180 / .pi
}

func syncLoadFirstVideoTrack(from asset: AVURLAsset) -> AVAssetTrack? {
    // Bridge the async API to sync for scripting
    let sema = DispatchSemaphore(value: 0)
    var out: AVAssetTrack?
    Task {
        out = try? await asset.loadTracks(withMediaType: .video).first
        sema.signal()
    }
    sema.wait()
    return out
}

// ---- resolve input/output paths ----
let argPath = CommandLine.arguments.dropFirst().first ?? "IMG_1569.mp4"
let videoURL = URL(fileURLWithPath: argPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL

guard FileManager.default.fileExists(atPath: videoURL.path) else {
    fputs("❌ Video not found at: \(videoURL.path)\n", stderr)
    exit(1)
}

let outURL = videoURL.deletingPathExtension().appendingPathExtension("txt")
FileManager.default.createFile(atPath: outURL.path, contents: nil, attributes: nil)
guard let outHandle = try? FileHandle(forWritingTo: outURL) else {
    fputs("❌ Could not open output file: \(outURL.path)\n", stderr)
    exit(1)
}
defer { try? outHandle.close() }

func writeLine(_ s: String) {
    if let data = (s + "\n").data(using: .utf8) {
        try? outHandle.seekToEnd()
        try? outHandle.write(contentsOf: data)
    }
}

// ---- load asset & track (modern API) ----
let asset = AVURLAsset(url: videoURL)
guard let track = syncLoadFirstVideoTrack(from: asset) else {
    fputs("❌ No video track found.\n", stderr)
    exit(1)
}

// ---- set up reader ----
guard let reader = try? AVAssetReader(asset: asset) else {
    fputs("❌ AVAssetReader init failed.\n", stderr)
    exit(1)
}
let settings: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
]
let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
output.alwaysCopiesSampleData = false

guard reader.canAdd(output) else {
    fputs("❌ Cannot add track output.\n", stderr)
    exit(1)
}
reader.add(output)
guard reader.startReading() else {
    fputs("❌ startReading failed: \(reader.error?.localizedDescription ?? "unknown")\n", stderr)
    exit(1)
}

// ---- Vision setup ----
let request = VNDetectHumanBodyPoseRequest()
let seq = VNSequenceRequestHandler()

let fmt = DateFormatter()
fmt.dateFormat = "HH:mm:ss.SSS"

print("▶️ Processing \(videoURL.lastPathComponent)")
writeLine("# Angles for \(videoURL.lastPathComponent)")
writeLine("# time, frame, left_elbow_deg, right_elbow_deg")

var frameIndex = 0

// ---- frame loop ----
while reader.status == .reading, let sample = output.copyNextSampleBuffer() {
    frameIndex += 1
    guard let pb = CMSampleBufferGetImageBuffer(sample) else { continue }

    do {
        try seq.perform([request], on: pb)
    } catch {
        continue
    }

    guard let obs = request.results?.first as? VNHumanBodyPoseObservation,
          let pts = try? obs.recognizedPoints(.all) else { continue }

    func loc(_ p: VNRecognizedPoint?) -> CGPoint? {
        guard let p = p, p.confidence > 0.5 else { return nil }
        return p.location
    }

    // left and right elbow angles
    let lSh = loc(pts[.leftShoulder]), lEl = loc(pts[.leftElbow]), lWr = loc(pts[.leftWrist])
    let rSh = loc(pts[.rightShoulder]), rEl = loc(pts[.rightElbow]), rWr = loc(pts[.rightWrist])

    let leftDeg  = (lSh != nil && lEl != nil && lWr != nil) ? angleAtB(lSh!, lEl!, lWr!) : .nan
    let rightDeg = (rSh != nil && rEl != nil && rWr != nil) ? angleAtB(rSh!, rEl!, rWr!) : .nan

    let ts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
    let tsStr = fmt.string(from: Date(timeIntervalSince1970: ts))

    let leftStr  = leftDeg.isNaN  ? "NaN" : String(format: "%.1f", leftDeg)
    let rightStr = rightDeg.isNaN ? "NaN" : String(format: "%.1f", rightDeg)

    let line = "\(tsStr), \(String(format: "%6d", frameIndex)), \(leftStr), \(rightStr)"
    print(line)
    writeLine(line)
}

switch reader.status {
case .completed:
    print("✅ Done. Saved: \(outURL.path)")
case .failed:
    print("❌ Reader failed: \(reader.error?.localizedDescription ?? "unknown")")
case .cancelled:
    print("⚠️ Reader cancelled")
default:
    break
}
