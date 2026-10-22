import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum CropError: LocalizedError {
    case unreadable, emptySelection, cannotEncode
    var errorDescription: String? {
        switch self {
        case .unreadable: return "无法读取这张图片，请尝试其他图片或格式。"
        case .emptySelection: return "请在图片内拖动，框选一个有效区域。"
        case .cannotEncode: return "无法生成 PNG 图片。"
        }
    }
}

enum CropEngine {
    static func load(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else { throw CropError.unreadable }
        // Normalize EXIF rotation/mirroring before display AND cropping.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CropError.unreadable
        }
        return image
    }

    static func pixelRect(selection: CGRect, displayedImage: CGRect, width: Int, height: Int) throws -> CGRect {
        guard displayedImage.width > 0, displayedImage.height > 0, width > 0, height > 0 else {
            throw CropError.emptySelection
        }
        let selected = selection.standardized.intersection(displayedImage)
        guard !selected.isNull, selected.width > 0, selected.height > 0 else { throw CropError.emptySelection }
        let sx = CGFloat(width) / displayedImage.width
        let sy = CGFloat(height) / displayedImage.height
        let x0 = max(0, floor((selected.minX - displayedImage.minX) * sx))
        let y0 = max(0, floor((selected.minY - displayedImage.minY) * sy))
        let x1 = min(CGFloat(width), ceil((selected.maxX - displayedImage.minX) * sx))
        let y1 = min(CGFloat(height), ceil((selected.maxY - displayedImage.minY) * sy))
        guard x1 > x0, y1 > y0 else { throw CropError.emptySelection }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    static func crop(_ image: CGImage, rect: CGRect) throws -> CGImage {
        let safe = rect.integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !safe.isNull, safe.width > 0, safe.height > 0,
              let cropped = image.cropping(to: safe) else { throw CropError.emptySelection }
        return cropped
    }

    static func save(_ image: CGImage, directory: URL, stem: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let buffer = NSMutableData()
        guard let encoder = CGImageDestinationCreateWithData(buffer, UTType.png.identifier as CFString, 1, nil) else {
            throw CropError.cannotEncode
        }
        CGImageDestinationAddImage(encoder, image, nil)
        guard CGImageDestinationFinalize(encoder) else { throw CropError.cannotEncode }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let stamp = formatter.string(from: Date())
        // Keep filenames short even when the source name approaches the filesystem limit.
        let prefix = String(stem.prefix(40))
        var suffix = 0
        while true {
            let extra = suffix == 0 ? "" : "_\(suffix)"
            let url = directory.appendingPathComponent("\(prefix)_裁剪_\(stamp)\(extra).png")
            do {
                try (buffer as Data).write(to: url, options: .withoutOverwriting)
                return url
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                suffix += 1
            }
        }
    }
}
