import AppKit
import QuartzCore

enum PetAnimation: String {
    case idle
    case hover
    case tap
    case cheer
    case sleep
    case talk
}

final class LightweightLottieView: NSView {
    private let contentLayer = CALayer()
    private var animation: LottieAnimation?
    private var renderLayers: [LottieRenderLayer] = []
    private var timer: Timer?
    private var startedAt = Date()
    private var currentAnimation: PetAnimation?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false

        contentLayer.backgroundColor = NSColor.clear.cgColor
        contentLayer.masksToBounds = false
        contentLayer.isGeometryFlipped = true
        layer?.addSublayer(contentLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutContentLayer()
    }

    @discardableResult
    func play(_ animationName: PetAnimation, restart: Bool = false) -> Bool {
        guard restart || animationName != currentAnimation else { return true }
        guard let url = Self.animationURL(for: animationName),
              let loadedAnimation = try? Self.loadAnimation(from: url)
        else {
            stop()
            return false
        }

        currentAnimation = animationName
        animation = loadedAnimation
        rebuildLayers(animation: loadedAnimation, baseURL: url.deletingLastPathComponent())
        startedAt = Date()
        isHidden = false
        layoutContentLayer()
        startTimer()
        updateFrame()
        return true
    }

    func stop() {
        currentAnimation = nil
        animation = nil
        timer?.invalidate()
        timer = nil
        renderLayers.removeAll()
        contentLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        isHidden = true
    }

    private func rebuildLayers(animation: LottieAnimation, baseURL: URL) {
        contentLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        renderLayers.removeAll()

        let assetsById = Dictionary(uniqueKeysWithValues: animation.assets.map { ($0.id, $0) })

        for sourceLayer in animation.layers where sourceLayer.type == 2 {
            guard let assetId = sourceLayer.refId,
                  let asset = assetsById[assetId],
                  let image = Self.image(for: asset, baseURL: baseURL),
                  let cgImage = Self.cgImage(from: image)
            else {
                continue
            }

            let layer = CALayer()
            layer.contents = cgImage
            layer.contentsGravity = .resize
            layer.magnificationFilter = .linear
            layer.minificationFilter = .trilinear
            layer.bounds = CGRect(x: 0, y: 0, width: CGFloat(asset.width), height: CGFloat(asset.height))
            layer.masksToBounds = false

            let anchor = sourceLayer.transform.anchor.value(at: 0, fallback: [CGFloat(asset.width) / 2, CGFloat(asset.height) / 2, 0])
            layer.anchorPoint = CGPoint(
                x: CGFloat(anchor[safe: 0] ?? CGFloat(asset.width) / 2) / CGFloat(asset.width),
                y: CGFloat(anchor[safe: 1] ?? CGFloat(asset.height) / 2) / CGFloat(asset.height)
            )

            contentLayer.addSublayer(layer)
            renderLayers.append(LottieRenderLayer(source: sourceLayer, asset: asset, layer: layer))
        }
    }

    private func layoutContentLayer() {
        guard let animation else {
            contentLayer.frame = bounds
            return
        }

        let width = CGFloat(animation.width)
        let height = CGFloat(animation.height)
        guard width > 0, height > 0, bounds.width > 0, bounds.height > 0 else { return }

        let scale = min(bounds.width / width, bounds.height / height)
        let origin = CGPoint(
            x: bounds.midX - width * scale / 2,
            y: bounds.midY - height * scale / 2
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        contentLayer.anchorPoint = .zero
        contentLayer.position = origin
        contentLayer.transform = CATransform3DMakeScale(scale, scale, 1)
        CATransaction.commit()
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFrame()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func updateFrame() {
        guard let animation else { return }

        let frameSpan = max(1, animation.outPoint - animation.inPoint)
        let elapsedFrames = Date().timeIntervalSince(startedAt) * animation.frameRate
        let frame = animation.inPoint + elapsedFrames.truncatingRemainder(dividingBy: frameSpan)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for renderLayer in renderLayers {
            applyFrame(frame, to: renderLayer)
        }
        CATransaction.commit()
    }

    private func applyFrame(_ frame: Double, to renderLayer: LottieRenderLayer) {
        let source = renderLayer.source
        let layer = renderLayer.layer
        let visible = frame >= source.inPoint && frame < source.outPoint
        layer.isHidden = !visible
        guard visible else { return }

        let transform = source.transform
        let position = transform.position.value(at: frame, fallback: [256, 256, 0])
        let scale = transform.scale.value(at: frame, fallback: [100, 100, 100])
        let rotation = transform.rotation.value(at: frame, fallback: [0])
        let opacity = transform.opacity.value(at: frame, fallback: [100])

        layer.position = CGPoint(
            x: position[safe: 0] ?? 0,
            y: position[safe: 1] ?? 0
        )
        layer.opacity = Float((opacity[safe: 0] ?? 100) / 100)

        var layerTransform = CATransform3DIdentity
        layerTransform = CATransform3DScale(
            layerTransform,
            (scale[safe: 0] ?? 100) / 100,
            (scale[safe: 1] ?? 100) / 100,
            1
        )
        layerTransform = CATransform3DRotate(
            layerTransform,
            ((rotation[safe: 0] ?? 0) * .pi) / 180,
            0,
            0,
            1
        )
        layer.transform = layerTransform
    }

    private static func animationURL(for animation: PetAnimation) -> URL? {
        let resourceName = animation.rawValue
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Animations/Pet") {
            return url
        }

        let localURL = URL(fileURLWithPath: "Resources/Animations/Pet/\(resourceName).json")
        return FileManager.default.fileExists(atPath: localURL.path) ? localURL : nil
    }

    private static func loadAnimation(from url: URL) throws -> LottieAnimation {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(LottieAnimation.self, from: data)
    }

    private static func image(for asset: LottieAsset, baseURL: URL) -> NSImage? {
        let relativePath = asset.folder + asset.path
        let bundledSubdirectory = "Animations/Pet/" + asset.folder.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if let url = Bundle.main.url(forResource: asset.path, withExtension: nil, subdirectory: bundledSubdirectory) {
            return NSImage(contentsOf: url)
        }

        let localURL = baseURL.appendingPathComponent(relativePath)
        return NSImage(contentsOf: localURL)
    }

    private static func cgImage(from image: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: [.interpolation: NSImageInterpolation.high])
    }
}

private struct LottieRenderLayer {
    let source: LottieLayer
    let asset: LottieAsset
    let layer: CALayer
}

private struct LottieAnimation: Decodable {
    let frameRate: Double
    let inPoint: Double
    let outPoint: Double
    let width: Double
    let height: Double
    let assets: [LottieAsset]
    let layers: [LottieLayer]

    private enum CodingKeys: String, CodingKey {
        case frameRate = "fr"
        case inPoint = "ip"
        case outPoint = "op"
        case width = "w"
        case height = "h"
        case assets
        case layers
    }
}

private struct LottieAsset: Decodable {
    let id: String
    let width: Int
    let height: Int
    let folder: String
    let path: String

    private enum CodingKeys: String, CodingKey {
        case id
        case width = "w"
        case height = "h"
        case folder = "u"
        case path = "p"
    }
}

private struct LottieLayer: Decodable {
    let type: Int
    let refId: String?
    let transform: LottieTransform
    let inPoint: Double
    let outPoint: Double

    private enum CodingKeys: String, CodingKey {
        case type = "ty"
        case refId
        case transform = "ks"
        case inPoint = "ip"
        case outPoint = "op"
    }
}

private struct LottieTransform: Decodable {
    let opacity: LottieAnimatedValue
    let rotation: LottieAnimatedValue
    let position: LottieAnimatedValue
    let anchor: LottieAnimatedValue
    let scale: LottieAnimatedValue

    private enum CodingKeys: String, CodingKey {
        case opacity = "o"
        case rotation = "r"
        case position = "p"
        case anchor = "a"
        case scale = "s"
    }
}

private struct LottieAnimatedValue: Decodable {
    let isAnimated: Bool
    let staticValue: [CGFloat]
    let keyframes: [LottieKeyframe]

    private enum CodingKeys: String, CodingKey {
        case isAnimated = "a"
        case value = "k"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isAnimated = (try? container.decode(Int.self, forKey: .isAnimated)) == 1

        if isAnimated {
            keyframes = try container.decode([LottieKeyframe].self, forKey: .value)
            staticValue = keyframes.first?.startValue ?? []
        } else {
            staticValue = try container.decode(LottieValue.self, forKey: .value).values
            keyframes = []
        }
    }

    func value(at frame: Double, fallback: [CGFloat]) -> [CGFloat] {
        if !isAnimated {
            return staticValue.isEmpty ? fallback : staticValue
        }

        guard let first = keyframes.first else { return fallback }
        if frame <= first.time {
            return first.startValue
        }

        for index in keyframes.indices {
            let current = keyframes[index]
            let next = keyframes.indices.contains(index + 1) ? keyframes[index + 1] : nil
            let endTime = next?.time ?? current.time

            if frame <= endTime {
                let endValue = current.endValue ?? next?.startValue ?? current.startValue
                guard endTime > current.time else { return endValue }
                let progress = max(0, min(1, (frame - current.time) / (endTime - current.time)))
                let easedProgress = 0.5 - 0.5 * cos(progress * .pi)
                return interpolate(from: current.startValue, to: endValue, progress: CGFloat(easedProgress))
            }
        }

        return keyframes.last?.startValue ?? fallback
    }

    private func interpolate(from start: [CGFloat], to end: [CGFloat], progress: CGFloat) -> [CGFloat] {
        let count = max(start.count, end.count)
        return (0..<count).map { index in
            let startValue = start[safe: index] ?? start.last ?? 0
            let endValue = end[safe: index] ?? end.last ?? startValue
            return startValue + (endValue - startValue) * progress
        }
    }
}

private struct LottieKeyframe: Decodable {
    let time: Double
    let startValue: [CGFloat]
    let endValue: [CGFloat]?

    private enum CodingKeys: String, CodingKey {
        case time = "t"
        case startValue = "s"
        case endValue = "e"
    }
}

private struct LottieValue: Decodable {
    let values: [CGFloat]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let scalar = try? container.decode(Double.self) {
            values = [CGFloat(scalar)]
        } else {
            values = try container.decode([Double].self).map { CGFloat($0) }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
