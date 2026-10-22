import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@main struct Tests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes: [UInt8] = (0..<16).flatMap { index -> [UInt8] in
            let x = index % 4, y = index / 4
            return [UInt8(y < 2 ? 255 : 0), UInt8(x >= 2 ? 255 : 0), UInt8(y >= 2 ? 255 : 0), 255]
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(width: 4, height: 4, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 16,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let mapped = try CropEngine.pixelRect(selection: CGRect(x: 30, y: 40, width: 20, height: 20), displayedImage: CGRect(x: 30, y: 40, width: 40, height: 40), width: 4, height: 4)
        precondition(mapped == CGRect(x: 0, y: 0, width: 2, height: 2))
        let crop = try CropEngine.crop(image, rect: mapped)
        let first = try CropEngine.save(crop, directory: directory, stem: "测试原图")
        let reloaded = try CropEngine.load(first)
        precondition(reloaded.width == 2 && reloaded.height == 2)
        // Compare decoded pixel content, catching vertical-coordinate inversions.
        var pixel = [UInt8](repeating: 0, count: 16)
        pixel.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(reloaded, in: CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        precondition(pixel[0] == 255 && pixel[1] == 0 && pixel[2] == 0)
        let originalBytes = try Data(contentsOf: first)
        for _ in 0..<5 {
            let next = try CropEngine.save(crop, directory: directory, stem: "测试原图")
            precondition(next != first)
        }
        let unchangedBytes = try Data(contentsOf: first)
        precondition(unchangedBytes == originalBytes)
        let entries = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        precondition(entries.count == 6)
        let clipped = try CropEngine.pixelRect(selection: CGRect(x: 20, y: 30, width: 30, height: 30), displayedImage: CGRect(x: 30, y: 40, width: 40, height: 40), width: 4, height: 4)
        precondition(clipped == mapped)
        do {
            _ = try CropEngine.pixelRect(selection: .zero, displayedImage: CGRect(x: 0, y: 0, width: 40, height: 40), width: 4, height: 4)
            fatalError("Empty selection accepted")
        } catch CropError.emptySelection {}
        // Orientation 6 must rotate a 4 x 2 source into a 2 x 4 image.
        let wide = image.cropping(to: CGRect(x: 0, y: 0, width: 4, height: 2))!
        let rotatedFile = directory.appendingPathComponent("orientation.jpg")
        let destination = CGImageDestinationCreateWithURL(rotatedFile as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, wide, [kCGImagePropertyOrientation: 6] as CFDictionary)
        precondition(CGImageDestinationFinalize(destination))
        let normalized = try CropEngine.load(rotatedFile)
        precondition(normalized.width == 2 && normalized.height == 4)
        print("PASS: crop coordinate mapping, pixel content, PNG output, unique names, bounds checking and EXIF rotation")
    }
}
