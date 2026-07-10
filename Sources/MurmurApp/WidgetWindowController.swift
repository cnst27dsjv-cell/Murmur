import AppKit

@MainActor
final class WidgetWindowController: NSWindowController, NSWindowDelegate {
    private enum Layout {
        static let collapsedSize = CGSize(width: 136, height: 136)
        static let expandedSize = CGSize(width: 520, height: 500)
        static let edgeInset: CGFloat = 10
    }

    private let store: AppStore
    private let widgetView: WidgetView
    private(set) var state: MurmurState

    init(state: MurmurState, store: AppStore) {
        var initialState = state
        let initialFrame = Self.frame(for: initialState, near: state.widget.frame.cgRect)
        initialState.widget.frame = StoredFrame(initialFrame)
        initialState.pet.edge = Self.petEdge(for: initialFrame)

        self.state = initialState
        self.store = store
        self.widgetView = WidgetView(state: initialState)

        let frame = initialState.widget.frame.cgRect
        let window = MurmurWidgetWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = widgetView

        super.init(window: window)
        window.delegate = self
        widgetView.onChange = { [weak self] newState in
            self?.apply(newState)
        }
        widgetView.onDragFinished = { [weak self] frame in
            self?.snapAfterDrag(frame)
        }
        widgetView.onRequestSettings = {
            (NSApp.delegate as? AppDelegate)?.showSettings()
        }
        widgetView.onRequestQuit = {
            (NSApp.delegate as? AppDelegate)?.quit()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    func toggleBlurred() {
        var newState = state
        newState.widget.isBlurred.toggle()
        apply(newState)
    }

    func showInlineSettings() {
        var newState = state
        newState.widget.isExpanded = true
        apply(newState)
        widgetView.showInlineSettings()
    }

    func apply(_ newState: MurmurState) {
        var adjustedState = newState
        let adjustedFrame = Self.frame(for: adjustedState, near: window?.frame ?? newState.widget.frame.cgRect)
        adjustedState.widget.frame = StoredFrame(adjustedFrame)
        adjustedState.pet.edge = Self.petEdge(for: adjustedFrame)

        state = adjustedState
        window?.setFrame(adjustedState.widget.frame.cgRect, display: true, animate: true)
        widgetView.apply(adjustedState)
        store.save(adjustedState)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()
    }

    func windowDidMove(_ notification: Notification) {
        persistWindowFrame()
    }

    func windowDidResize(_ notification: Notification) {
        persistWindowFrame()
    }

    private func persistWindowFrame() {
        guard let frame = window?.frame else { return }
        state.widget.frame = StoredFrame(frame)
        store.save(state)
    }

    private func snapAfterDrag(_ frame: CGRect) {
        var newState = state
        newState.widget.frame = StoredFrame(Self.frame(for: newState, near: frame))
        apply(newState)
    }

    private static func frame(for state: MurmurState, near frame: CGRect) -> CGRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = state.widget.isExpanded ? Layout.expandedSize : Layout.collapsedSize
        let x: CGFloat

        if frame.midX < screenFrame.midX {
            x = screenFrame.minX + Layout.edgeInset
        } else {
            x = screenFrame.maxX - size.width - Layout.edgeInset
        }

        let proposedY = frame.midY - size.height / 2
        let y = min(max(proposedY, screenFrame.minY + Layout.edgeInset), screenFrame.maxY - size.height - Layout.edgeInset)

        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    private static func petEdge(for frame: CGRect) -> PetEdge {
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return frame.midX < screenFrame.midX ? .topRight : .topLeft
    }
}

final class MurmurWidgetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension StoredFrame {
    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    init(_ rect: CGRect) {
        self.init(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
    }
}
