import AppKit
import CoreImage
import Vision

enum PetForegroundExtractionError: LocalizedError {
    case unreadableImage
    case noForeground
    case unsupportedMask
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "无法读取这张图片。"
        case .noForeground:
            return "没有识别到清晰的桌宠主体。"
        case .unsupportedMask:
            return "当前图片生成的蒙版格式暂不受支持。"
        case .renderFailed:
            return "透明图片生成失败。"
        }
    }
}

enum PetForegroundExtractor {
    static func extractPNG(from sourceURL: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try extractPNGSynchronously(from: sourceURL)
        }.value
    }

    private static func extractPNGSynchronously(from sourceURL: URL) throws -> Data {
        guard let inputImage = CIImage(
            contentsOf: sourceURL,
            options: [.applyOrientationProperty: true]
        ) else {
            throw PetForegroundExtractionError.unreadableImage
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: inputImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw PetForegroundExtractionError.noForeground
        }

        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: handler
        )
        let maskImage = CIImage(cvPixelBuffer: maskBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let cropRect = try foregroundBounds(
            in: maskImage,
            imageExtent: inputImage.extent,
            context: context
        )
        let transparentBackground = CIImage(color: .clear).cropped(to: inputImage.extent)
        let foreground = inputImage.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: transparentBackground,
                kCIInputMaskImageKey: maskImage
            ]
        ).cropped(to: cropRect)

        guard let cgImage = context.createCGImage(foreground, from: cropRect) else {
            throw PetForegroundExtractionError.renderFailed
        }

        let representation = NSBitmapImageRep(cgImage: cgImage)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw PetForegroundExtractionError.renderFailed
        }
        return data
    }

    private static func foregroundBounds(
        in maskImage: CIImage,
        imageExtent: CGRect,
        context: CIContext
    ) throws -> CGRect {
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        guard let maskCGImage = context.createCGImage(
            maskImage,
            from: maskImage.extent,
            format: .L8,
            colorSpace: grayColorSpace
        ),
        let pixelData = maskCGImage.dataProvider?.data,
        let pixels = CFDataGetBytePtr(pixelData)
        else {
            throw PetForegroundExtractionError.unsupportedMask
        }

        let width = maskCGImage.width
        let height = maskCGImage.height
        let bytesPerRow = maskCGImage.bytesPerRow
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        for y in 0..<height {
            let row = pixels.advanced(by: y * bytesPerRow)
            for x in 0..<width where row[x] > 20 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x + 1)
                maxY = max(maxY, y + 1)
            }
        }

        guard minX < maxX, minY < maxY else {
            throw PetForegroundExtractionError.noForeground
        }

        let padding = max(8, Int(Double(max(width, height)) * 0.035))
        minX = max(0, minX - padding)
        minY = max(0, minY - padding)
        maxX = min(width, maxX + padding)
        maxY = min(height, maxY + padding)

        let scaleX = imageExtent.width / CGFloat(width)
        let scaleY = imageExtent.height / CGFloat(height)
        return CGRect(
            x: imageExtent.minX + CGFloat(minX) * scaleX,
            y: imageExtent.minY + CGFloat(height - maxY) * scaleY,
            width: CGFloat(maxX - minX) * scaleX,
            height: CGFloat(maxY - minY) * scaleY
        ).intersection(imageExtent)
    }
}

@MainActor
enum PetImageImporter {
    static func importImage(from sourceURL: URL, presenting window: NSWindow?) async -> String? {
        do {
            let cutoutData = try await PetForegroundExtractor.extractPNG(from: sourceURL)
            let response = await presentPreview(for: cutoutData, window: window)
            switch response {
            case .alertFirstButtonReturn:
                return try save(data: cutoutData, fileExtension: "png").path
            case .alertSecondButtonReturn:
                return try saveOriginalImage(from: sourceURL).path
            default:
                return nil
            }
        } catch {
            let response = await presentFailure(error: error, window: window)
            guard response == .alertFirstButtonReturn else { return nil }
            do {
                return try saveOriginalImage(from: sourceURL).path
            } catch {
                presentSaveFailure(error: error, window: window)
                return nil
            }
        }
    }

    private static func presentPreview(
        for data: Data,
        window: NSWindow?
    ) async -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "自动抠图完成"
        alert.informativeText = "请确认边缘是否完整。图片只在本机处理。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "使用抠图结果")
        alert.addButton(withTitle: "使用原图")
        alert.addButton(withTitle: "取消")
        if let image = NSImage(data: data) {
            alert.accessoryView = CutoutPreviewView(image: image)
        }
        return await run(alert: alert, window: window)
    }

    private static func presentFailure(
        error: Error,
        window: NSWindow?
    ) async -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "自动抠图失败"
        alert.informativeText = "\(error.localizedDescription)\n你仍然可以使用原图。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "使用原图")
        alert.addButton(withTitle: "取消")
        return await run(alert: alert, window: window)
    }

    private static func presentSaveFailure(error: Error, window: NSWindow?) {
        let alert = NSAlert(error: error)
        alert.messageText = "桌宠图片保存失败"
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private static func run(
        alert: NSAlert,
        window: NSWindow?
    ) async -> NSApplication.ModalResponse {
        guard let window else { return alert.runModal() }
        return await withCheckedContinuation { continuation in
            alert.beginSheetModal(for: window) { response in
                continuation.resume(returning: response)
            }
        }
    }

    private static func save(data: Data, fileExtension: String) throws -> URL {
        let directory = try customPetDirectory()
        let destination = directory
            .appendingPathComponent("pet-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private static func saveOriginalImage(from sourceURL: URL) throws -> URL {
        let directory = try customPetDirectory()
        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let destination = directory
            .appendingPathComponent("pet-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    private static func customPetDirectory() throws -> URL {
        let fileManager = FileManager.default
        let base: URL
        if let devPath = ProcessInfo.processInfo.environment["MURMUR_DEV_DATA_DIR"], !devPath.isEmpty {
            base = URL(fileURLWithPath: devPath, isDirectory: true)
        } else {
            base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Murmur", isDirectory: true)
        }
        let directory = base.appendingPathComponent("CustomPets", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private final class CutoutPreviewView: NSView {
    private let image: NSImage

    init(image: NSImage) {
        self.image = image
        super.init(frame: CGRect(x: 0, y: 0, width: 280, height: 240))
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let tileSize: CGFloat = 12
        for row in 0...Int(bounds.height / tileSize) {
            for column in 0...Int(bounds.width / tileSize) {
                let isLight = (row + column).isMultiple(of: 2)
                (isLight ? NSColor.white : NSColor(calibratedWhite: 0.90, alpha: 1)).setFill()
                CGRect(
                    x: CGFloat(column) * tileSize,
                    y: CGFloat(row) * tileSize,
                    width: tileSize,
                    height: tileSize
                ).fill()
            }
        }

        let available = bounds.insetBy(dx: 12, dy: 12)
        let scale = min(available.width / image.size.width, available.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let destination = CGRect(
            x: available.midX - size.width / 2,
            y: available.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
    }
}
