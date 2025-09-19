# JabTimer - Video Punch Analysis Tool

A Swift-based tool for analyzing boxing/martial arts punches from video files using computer vision and elbow angle measurements.

## Overview

JabTimer processes video files to:
1. Extract human pose data using Apple's Vision framework
2. Calculate elbow angles frame by frame  
3. Analyze punch motions and calculate speed metrics
4. Generate detailed reports on punch performance

## Files

- `main.swift` - Video processor that extracts elbow angles from MP4 files
- `punch_analyzer.swift` - Analyzes angle data to detect punches and calculate speed
- `annie_jab.txt` - Example output file with angle measurements

## Requirements

- macOS with Swift 6.0+
- AVFoundation framework (for video processing)
- Vision framework (for human pose detection)

## Usage

### Step 1: Extract Angle Data from Video

```bash
swift main.swift your_video.mp4
```

This will:
- Process the video file frame by frame
- Detect human poses using Vision framework
- Calculate left and right elbow angles
- Output results to `your_video.txt`

**Input**: MP4 video file showing punching motion
**Output**: Text file with timestamp, frame number, left elbow angle, right elbow angle

### Step 2: Analyze Punch Metrics

```bash
swift punch_analyzer.swift your_video.txt
```

This will:
- Parse the angle data file
- Detect significant punch motions (>30° angle change)
- Calculate punch speed in degrees per second
- Generate summary statistics

## Output Format

### Angle Data File (`.txt`)
```
# Angles for video.mp4
# time, frame, left_elbow_deg, right_elbow_deg
16:00:00.000,      1, 10.6, 10.0
16:00:00.033,      2, 11.5, 9.6
...
```

### Punch Analysis Report
```
=== PUNCH ANALYSIS RESULTS ===
Found 16 significant punch motions

Punch #1 (Left arm):
  Min angle: 0.5° at 16:00:00.133
  Max angle: 156.8° at 16:00:00.300
  Duration: 0.167s
  Angle change: 156.3°
  Speed: 935.9°/s

=== SUMMARY ===
Left arm punches: 8
  Average speed: 473.9°/s
  Max speed: 935.9°/s
Right arm punches: 8
  Average speed: 268.3°/s
  Max speed: 717.3°/s
```

## How It Works

### Angle Calculation
The tool calculates elbow angles using the shoulder-elbow-wrist joint positions:
- Uses Vision framework's human pose detection
- Computes angle at elbow joint using vector mathematics
- Handles missing data points with NaN values

### Punch Detection Algorithm
1. Scans for significant angle changes (>30°)
2. Finds minimum and maximum angles within time windows
3. Calculates duration between min/max points
4. Computes speed as angle change per unit time
5. Filters overlapping detections

### Speed Metrics
- **Speed**: Degrees per second of elbow extension/flexion
- **Duration**: Time from minimum to maximum angle
- **Angle Change**: Total degrees of elbow movement
- **Summary Stats**: Average and maximum speeds per arm

## Example Analysis

Using the provided `annie_jab.mp4`:
- **16 punch motions detected** over 15 seconds
- **Left arm**: Faster average speed (473.9°/s)
- **Right arm**: More consistent but slower (268.3°/s)
- **Fastest punch**: 935.9°/s left jab in 0.167 seconds

## Troubleshooting

**Video not found**: Ensure the MP4 file is in the current directory
**No pose detected**: Video should clearly show a person from the side or front
**Compilation errors**: Make sure you're using Swift 6.0+ with AVFoundation support

## Technical Notes

- Uses synchronous AVFoundation APIs for Swift 6 compatibility
- Processes at 30fps video rate (~33ms per frame)
- Requires clear view of arms and joints for accurate detection
- NaN values indicate frames where pose detection failed

## Future Enhancements

- Real-time video analysis
- 3D angle calculations
- Punch classification (jab, cross, hook)
- Comparative analysis between sessions
- Export to CSV/JSON formats