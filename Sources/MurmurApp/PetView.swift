import AppKit

final class PetView: NSView {
    private var pet: PetState = MurmurState.defaultValue.pet
    private var image: NSImage?
    private var lastAppliedPet: PetState?
    private let animationView = LightweightLottieView()
    private let spriteSheetView = SpriteSheetPetView()
    private var trackingArea: NSTrackingArea?
    private var restoreWorkItem: DispatchWorkItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(spriteSheetView)
        addSubview(animationView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ pet: PetState) {
        guard pet != lastAppliedPet else { return }
        lastAppliedPet = pet
        self.pet = pet

        restoreWorkItem?.cancel()
        restoreWorkItem = nil

        if pet.kind == .customImage, let path = pet.imagePath {
            animationView.stop()
            spriteSheetView.stop()
            image = NSImage(contentsOfFile: path) ?? Self.builtInImage(for: pet.pose)
        } else {
            restoreBaseRenderer()
        }
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        spriteSheetView.frame = bounds
        animationView.frame = bounds
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        showStaticPose()
    }

    override func mouseExited(with event: NSEvent) {
        restoreBaseRenderer()
    }

    func playInteraction(_ animation: PetAnimation) {
        guard pet.kind == .builtIn else { return }

        restoreWorkItem?.cancel()
        image = nil
        spriteSheetView.stop()
        needsDisplay = true

        guard animationView.play(animation, restart: true) else {
            restoreBaseRenderer()
            return
        }

        let shouldReturnToIdle = animation != .hover && animation != .sleep
        guard shouldReturnToIdle else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.restoreBaseRenderer()
        }
        restoreWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + animation.displayDuration, execute: workItem)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard animationView.isHidden, spriteSheetView.isHidden else { return }

        if let image {
            image.draw(
                in: aspectFitRect(for: image, in: bounds),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return
        }

        let bodyRect = bounds.insetBy(dx: 10, dy: 12)
        NSColor(calibratedRed: 0.95, green: 0.91, blue: 0.84, alpha: 1).setFill()
        NSBezierPath(roundedRect: bodyRect, xRadius: 22, yRadius: 22).fill()

        NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
        NSBezierPath(ovalIn: CGRect(x: bodyRect.minX + 20, y: bodyRect.midY + 3, width: 6, height: 6)).fill()
        NSBezierPath(ovalIn: CGRect(x: bodyRect.maxX - 26, y: bodyRect.midY + 3, width: 6, height: 6)).fill()

        let mouth = NSBezierPath()
        mouth.move(to: CGPoint(x: bodyRect.midX - 6, y: bodyRect.midY - 8))
        mouth.curve(to: CGPoint(x: bodyRect.midX + 6, y: bodyRect.midY - 8), controlPoint1: CGPoint(x: bodyRect.midX - 2, y: bodyRect.midY - 13), controlPoint2: CGPoint(x: bodyRect.midX + 2, y: bodyRect.midY - 13))
        mouth.lineWidth = 1.6
        NSColor(calibratedWhite: 0.22, alpha: 0.85).setStroke()
        mouth.stroke()
    }

    private func aspectFitRect(for image: NSImage, in rect: CGRect) -> CGRect {
        guard image.size.width > 0, image.size.height > 0 else { return rect }

        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let width = image.size.width * scale
        let height = image.size.height * scale
        return CGRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func restoreBaseRenderer() {
        restoreWorkItem?.cancel()
        restoreWorkItem = nil

        if pet.kind == .customImage {
            spriteSheetView.stop()
            animationView.stop()
            image = pet.imagePath.flatMap { NSImage(contentsOfFile: $0) }
                ?? Self.builtInImage(for: pet.pose)
            needsDisplay = true
            return
        }

        if pet.kind == .builtIn, spriteSheetView.play(pose: pet.pose) {
            animationView.stop()
            image = nil
            needsDisplay = true
            return
        }

        spriteSheetView.stop()
        animationView.stop()
        image = Self.builtInImage(for: pet.pose)
        needsDisplay = true
    }

    private func showStaticPose() {
        guard pet.kind == .builtIn else { return }

        restoreWorkItem?.cancel()
        restoreWorkItem = nil
        if spriteSheetView.showStill(pose: pet.pose) {
            animationView.stop()
            image = nil
            needsDisplay = true
            return
        }

        spriteSheetView.stop()
        animationView.stop()
        image = Self.builtInImage(for: pet.pose)
        needsDisplay = true
    }

    private static func builtInImage(for pose: PetPose) -> NSImage? {
        if let url = Bundle.main.url(forResource: pose.resourceName, withExtension: "png", subdirectory: "Pets/cat") {
            return NSImage(contentsOf: url)
        }

        let localPath = "Resources/Pets/cat/\(pose.resourceName).png"
        return NSImage(contentsOfFile: localPath)
    }
}

final class SpriteSheetPetView: NSView {
    private let frameCount = 8
    private var frames: [NSImage] = []
    private var frameCanvasSize: CGSize = .zero
    private var frameIndex = 0
    private var frameSequence: [Int] = []
    private var sequenceIndex = 0
    private var timer: Timer?
    private var currentPose: PetPose?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isHidden = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func play(pose: PetPose) -> Bool {
        guard loadFramesIfNeeded(for: pose) else {
            stop()
            return false
        }

        isHidden = false
        startTimer(for: pose)
        needsDisplay = true
        return true
    }

    func showStill(pose: PetPose) -> Bool {
        guard loadFramesIfNeeded(for: pose) else {
            stop()
            return false
        }

        timer?.invalidate()
        timer = nil
        sequenceIndex = 0
        frameIndex = frameSequence.first ?? 0
        isHidden = false
        needsDisplay = true
        return true
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentPose = nil
        frames = []
        frameCanvasSize = .zero
        frameIndex = 0
        frameSequence = []
        sequenceIndex = 0
        isHidden = true
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard frames.indices.contains(frameIndex) else { return }

        let frame = frames[frameIndex]
        frame.draw(
            in: aspectFitRect(for: frameCanvasSize, in: bounds),
            from: CGRect(origin: .zero, size: frame.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func startTimer(for pose: PetPose) {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: pose.spriteFrameDuration, target: self, selector: #selector(advanceFrame), userInfo: nil, repeats: true)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func advanceFrame() {
        guard !frames.isEmpty, !frameSequence.isEmpty else { return }
        sequenceIndex = (sequenceIndex + 1) % frameSequence.count
        frameIndex = frameSequence[sequenceIndex]
        needsDisplay = true
    }

    private func loadFramesIfNeeded(for pose: PetPose) -> Bool {
        if currentPose == pose, !frames.isEmpty {
            return true
        }

        guard let loadedFrames = Self.frameImages(for: pose, frameCount: frameCount) else {
            return false
        }

        currentPose = pose
        frames = loadedFrames
        frameCanvasSize = loadedFrames[0].size
        frameSequence = pose.spriteFrameSequence(frameCount: loadedFrames.count)
        sequenceIndex = 0
        frameIndex = frameSequence.first ?? 0
        return true
    }

    private func aspectFitRect(for sourceSize: CGSize, in rect: CGRect) -> CGRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return rect }
        let scale = min(rect.width / sourceSize.width, rect.height / sourceSize.height)
        let width = sourceSize.width * scale
        let height = sourceSize.height * scale
        return CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
    }

    private static func frameImages(for pose: PetPose, frameCount: Int) -> [NSImage]? {
        var images: [NSImage] = []

        for index in 1...frameCount {
            let resourceName = String(format: "%@_%02d", pose.resourceName, index)
            let image: NSImage?
            if let url = Bundle.main.url(
                forResource: resourceName,
                withExtension: "png",
                subdirectory: "Pets/cat/frames"
            ) {
                image = NSImage(contentsOf: url)
            } else {
                image = NSImage(contentsOfFile: "Resources/Pets/cat/frames/\(resourceName).png")
            }

            guard let image else { return nil }
            images.append(image)
        }

        return images
    }
}

private extension PetPose {
    var spriteFrameDuration: TimeInterval {
        switch self {
        case .catSleep:
            return 0.22
        case .catCookie, .catYarn, .catBox:
            return 0.15
        case .catSit:
            return 0.30
        case .catDefault:
            return 0.13
        }
    }

    func spriteFrameSequence(frameCount: Int) -> [Int] {
        guard frameCount > 0 else { return [] }
        guard self == .catSit, frameCount > 1 else {
            return Array(0..<frameCount)
        }

        let forward = Array(0..<frameCount)
        let backward = Array(stride(from: frameCount - 2, through: 1, by: -1))
        let pause = Array(repeating: 0, count: 3)
        return forward + backward + pause
    }
}

private extension PetAnimation {
    var displayDuration: TimeInterval {
        switch self {
        case .tap:
            return 1.0
        case .cheer:
            return 1.7
        case .talk:
            return 1.8
        case .idle, .hover, .sleep:
            return 0
        }
    }
}
