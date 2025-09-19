import Foundation

struct AngleData {
    let timestamp: Double
    let frame: Int
    let leftAngle: Double?
    let rightAngle: Double?
}

struct PunchMetrics {
    let arm: String
    let minAngle: Double
    let maxAngle: Double
    let minTime: Double
    let maxTime: Double
    let duration: Double
    let angleChange: Double
    let speed: Double // degrees per second
}

class PunchAnalyzer {
    private var angleData: [AngleData] = []
    
    func parseFile(at path: String) throws {
        let content = try String(contentsOfFile: path)
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("#") || line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            
            let components = line.components(separatedBy: ",")
            guard components.count >= 4 else { continue }
            
            let timeStr = components[0].trimmingCharacters(in: .whitespaces)
            let frameStr = components[1].trimmingCharacters(in: .whitespaces)
            let leftStr = components[2].trimmingCharacters(in: .whitespaces)
            let rightStr = components[3].trimmingCharacters(in: .whitespaces)
            
            guard let frame = Int(frameStr) else { continue }
            
            let timestamp = parseTimestamp(timeStr)
            let leftAngle = leftStr == "NaN" ? nil : Double(leftStr)
            let rightAngle = rightStr == "NaN" ? nil : Double(rightStr)
            
            angleData.append(AngleData(
                timestamp: timestamp,
                frame: frame,
                leftAngle: leftAngle,
                rightAngle: rightAngle
            ))
        }
    }
    
    private func parseTimestamp(_ timeStr: String) -> Double {
        let components = timeStr.components(separatedBy: ":")
        guard components.count == 3 else { return 0 }
        
        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    func findPunches() -> [PunchMetrics] {
        var metrics: [PunchMetrics] = []
        
        // Analyze left arm
        if let leftMetrics = analyzePunches(for: "left") {
            metrics.append(contentsOf: leftMetrics)
        }
        
        // Analyze right arm
        if let rightMetrics = analyzePunches(for: "right") {
            metrics.append(contentsOf: rightMetrics)
        }
        
        return metrics
    }
    
    private func analyzePunches(for arm: String) -> [PunchMetrics]? {
        let validData = angleData.compactMap { data -> (Double, Double)? in
            let angle = arm == "left" ? data.leftAngle : data.rightAngle
            guard let angle = angle else { return nil }
            return (data.timestamp, angle)
        }
        
        guard validData.count > 10 else { return nil }
        
        var punches: [PunchMetrics] = []
        var i = 0
        
        while i < validData.count - 5 {
            // Look for significant angle changes (potential punch)
            let startAngle = validData[i].1
            var maxAngle = startAngle
            var minAngle = startAngle
            var maxTime = validData[i].0
            var minTime = validData[i].0
            
            // Scan forward for a complete punch motion
            var j = i + 1
            var foundSignificantChange = false
            
            while j < min(i + 30, validData.count) { // Look ahead 30 frames max
                let currentAngle = validData[j].1
                let currentTime = validData[j].0
                
                if currentAngle > maxAngle {
                    maxAngle = currentAngle
                    maxTime = currentTime
                }
                
                if currentAngle < minAngle {
                    minAngle = currentAngle
                    minTime = currentTime
                }
                
                // Check if we have a significant punch motion
                if abs(maxAngle - minAngle) > 30.0 { // At least 30 degree change
                    foundSignificantChange = true
                }
                
                j += 1
            }
            
            if foundSignificantChange && abs(maxAngle - minAngle) > 30.0 {
                let duration = abs(maxTime - minTime)
                let angleChange = abs(maxAngle - minAngle)
                let speed = duration > 0 ? angleChange / duration : 0
                
                punches.append(PunchMetrics(
                    arm: arm,
                    minAngle: minAngle,
                    maxAngle: maxAngle,
                    minTime: minTime,
                    maxTime: maxTime,
                    duration: duration,
                    angleChange: angleChange,
                    speed: speed
                ))
                
                // Skip ahead to avoid overlapping detections
                i = j
            } else {
                i += 1
            }
        }
        
        return punches.isEmpty ? nil : punches
    }
    
    func printResults() {
        let punches = findPunches()
        
        print("=== PUNCH ANALYSIS RESULTS ===")
        print("Found \(punches.count) significant punch motions\n")
        
        for (index, punch) in punches.enumerated() {
            let minTimeFormatted = formatTime(punch.minTime)
            let maxTimeFormatted = formatTime(punch.maxTime)
            
            print("Punch #\(index + 1) (\(punch.arm.capitalized) arm):")
            print("  Min angle: \(String(format: "%.1f", punch.minAngle))° at \(minTimeFormatted)")
            print("  Max angle: \(String(format: "%.1f", punch.maxAngle))° at \(maxTimeFormatted)")
            print("  Duration: \(String(format: "%.3f", punch.duration))s")
            print("  Angle change: \(String(format: "%.1f", punch.angleChange))°")
            print("  Speed: \(String(format: "%.1f", punch.speed))°/s")
            print("")
        }
        
        // Summary statistics
        if !punches.isEmpty {
            let leftPunches = punches.filter { $0.arm == "left" }
            let rightPunches = punches.filter { $0.arm == "right" }
            
            print("=== SUMMARY ===")
            print("Left arm punches: \(leftPunches.count)")
            if !leftPunches.isEmpty {
                let avgSpeed = leftPunches.map { $0.speed }.reduce(0, +) / Double(leftPunches.count)
                let maxSpeed = leftPunches.map { $0.speed }.max() ?? 0
                print("  Average speed: \(String(format: "%.1f", avgSpeed))°/s")
                print("  Max speed: \(String(format: "%.1f", maxSpeed))°/s")
            }
            
            print("Right arm punches: \(rightPunches.count)")
            if !rightPunches.isEmpty {
                let avgSpeed = rightPunches.map { $0.speed }.reduce(0, +) / Double(rightPunches.count)
                let maxSpeed = rightPunches.map { $0.speed }.max() ?? 0
                print("  Average speed: \(String(format: "%.1f", avgSpeed))°/s")
                print("  Max speed: \(String(format: "%.1f", maxSpeed))°/s")
            }
        }
    }
    
    private func formatTime(_ timestamp: Double) -> String {
        let hours = Int(timestamp / 3600)
        let minutes = Int((timestamp.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = timestamp.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%02d:%06.3f", hours, minutes, seconds)
    }
}

// Main execution
let analyzer = PunchAnalyzer()

do {
    let filePath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "annie_jab.txt"
    try analyzer.parseFile(at: filePath)
    analyzer.printResults()
} catch {
    print("Error: \(error)")
    exit(1)
}