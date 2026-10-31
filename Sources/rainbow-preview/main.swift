// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Renders Touch Bar-sized frames of the rainbow animation as PPM images so the look can be
// reviewed without a Mac. Convert them with e.g. `scripts/make-preview.sh`.
//
// Usage: rainbow-preview <output-dir> [--frames N] [--fps F] [--speed slow|normal|fast]

import Foundation
import RainbowCore

var args = Array(CommandLine.arguments.dropFirst())
guard let outDir = args.first, !outDir.hasPrefix("--") else {
    FileHandle.standardError.write(Data("usage: rainbow-preview <output-dir> [--frames N] [--fps F] [--speed slow|normal|fast]\n".utf8))
    exit(2)
}
args.removeFirst()

var frames = 30
var fps = 10.0
var style = RainbowStyle.default
while !args.isEmpty {
    let flag = args.removeFirst()
    guard let value = args.first else { break }
    args.removeFirst()
    switch flag {
    case "--frames": frames = Int(value) ?? frames
    case "--fps": fps = Double(value) ?? fps
    case "--speed": style.period = (Speed(rawValue: value) ?? .normal).period
    default: FileHandle.standardError.write(Data("ignoring unknown option \(flag)\n".utf8))
    }
}

let renderer = FrameRenderer(style: style)
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for i in 0..<frames {
    let image = renderer.render(time: Double(i) / fps)
    let path = (outDir as NSString).appendingPathComponent(String(format: "frame-%03d.ppm", i))
    try image.ppmData().write(to: URL(fileURLWithPath: path))
}
print("wrote \(frames) frames (\(renderer.width)x\(renderer.height) pt @\(renderer.scale)x) to \(outDir)")
