import AppKit

final class WidgetView: NSView {
    var onChange: ((MurmurState) -> Void)?
    var onDragFinished: ((CGRect) -> Void)?
    var onRequestSettings: (() -> Void)?
    var onRequestQuit: (() -> Void)?

    private var state: MurmurState
    private let cardView = NSVisualEffectView()
    private let railView = NSVisualEffectView()
    private let railGripView = RailGripView()
    private let railLabel = NSTextField(labelWithString: "Murmur")
    private let contentStack = NSStackView()
    private let themeBackgroundView = WidgetThemeBackgroundView()
    private let coverView = CoverView()
    private let petView = PetView()
    private let settingsPanel = NSVisualEffectView()
    private let settingsScrollView = NSScrollView()
    private let inlinePhraseField = FirstMouseTextField()
    private let inlineNoteField = FirstMouseTextField()
    private let inlineCoverField = FirstMouseTextField()
    private let inlineThemePopup = FirstMousePopUpButton()
    private let inlineCoverModePopup = FirstMousePopUpButton()
    private let inlinePetKindPopup = FirstMousePopUpButton()
    private let inlinePetPosePopup = FirstMousePopUpButton()
    private let inlineShowPhraseCheckbox = FirstMouseButton(checkboxWithTitle: "显示主文案", target: nil, action: nil)
    private let inlineShowNoteCheckbox = FirstMouseButton(checkboxWithTitle: "显示碎碎念", target: nil, action: nil)
    private let inlineShowTasksCheckbox = FirstMouseButton(checkboxWithTitle: "显示 to-do list", target: nil, action: nil)
    private let inlineExpandedCheckbox = FirstMouseButton(checkboxWithTitle: "展开完整组件", target: nil, action: nil)
    private let inlineBlurredCheckbox = FirstMouseButton(checkboxWithTitle: "启用模糊封面", target: nil, action: nil)
    private let inlineTaskStack = NSStackView()
    private var inlineTaskFields: [UUID: NSTextField] = [:]
    private var inlineTaskChecks: [UUID: NSButton] = [:]
    private var inlineTaskDeleteButtons: [UUID: NSButton] = [:]
    private var inlineUploadCoverButton: NSButton?
    private var inlineClearCoverButton: NSButton?
    private var inlineUploadCoverBackgroundButton: NSButton?
    private var inlineClearCoverBackgroundButton: NSButton?
    private var inlineAddTaskButton: NSButton?
    private var inlineDeleteCompletedButton: NSButton?
    private var inlineSaveButton: NSButton?
    private var inlineCloseButton: NSButton?
    private var inlineQuitButton: NSButton?
    private var inlineUploadPetButton: NSButton?
    private var inlineClearPetButton: NSButton?
    private var isShowingInlineSettings = false
    private var inlineDraftState: MurmurState?
    private var inlineOriginalState: MurmurState?
    private var mouseDownScreenPoint: CGPoint?
    private var mouseDownWindowOrigin: CGPoint?
    private var mouseDownStartedInInlineSettings = false
    private var didDragWindow = false

    init(state: MurmurState) {
        self.state = state
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupViews()
        apply(state, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }

        if !settingsPanel.isHidden {
            if inlineClickTarget(at: point) != nil {
                return self
            }

            let settingsPoint = convert(point, to: settingsPanel)
            if let hitView = settingsPanel.hitTest(settingsPoint) {
                return hitView
            }
        }

        if !isEffectivelyBlurred(state) {
            for button in contentTaskButtons(in: contentStack) {
                let buttonPoint = convert(point, to: button)
                if let hitView = button.hitTest(buttonPoint) {
                    return hitView
                }
            }
        }

        return self
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        let point = convert(event.locationInWindow, from: nil)
        mouseDownStartedInInlineSettings = isShowingInlineSettings && settingsPanel.frame.contains(point)
        mouseDownScreenPoint = NSEvent.mouseLocation
        mouseDownWindowOrigin = window?.frame.origin
        didDragWindow = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !mouseDownStartedInInlineSettings else { return }
        guard let mouseDownScreenPoint, let mouseDownWindowOrigin, let window else { return }

        let currentPoint = NSEvent.mouseLocation
        let deltaX = currentPoint.x - mouseDownScreenPoint.x
        let deltaY = currentPoint.y - mouseDownScreenPoint.y

        if abs(deltaX) > 3 || abs(deltaY) > 3 {
            didDragWindow = true
        }

        guard didDragWindow else { return }
        window.setFrameOrigin(CGPoint(x: mouseDownWindowOrigin.x + deltaX, y: mouseDownWindowOrigin.y + deltaY))
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownScreenPoint = nil
            mouseDownWindowOrigin = nil
            mouseDownStartedInInlineSettings = false
            didDragWindow = false
        }

        if didDragWindow {
            if let frame = window?.frame {
                onDragFinished?(frame)
            }
            return
        }

        if event.clickCount >= 2 {
            showInlineSettings()
            return
        }

        let point = convert(event.locationInWindow, from: nil)

        if handleInlineSettingsFallbackClick(at: point) {
            return
        }

        if handleContentTaskClick(at: point) {
            return
        }

        var nextState = state
        let didUsePetInteraction = petView.frame.contains(point) || !state.widget.isExpanded
        if didUsePetInteraction {
            nextState.widget.isExpanded.toggle()
            if !nextState.cover.isEnabled {
                nextState.widget.isBlurred = false
            }
        } else if state.cover.isEnabled {
            nextState.widget.isBlurred.toggle()
        } else {
            nextState.widget.isBlurred = false
        }
        onChange?(nextState)
        if didUsePetInteraction {
            petView.playInteraction(.tap)
        }
    }

    private func contentFrame(for theme: WidgetTheme, in rect: CGRect) -> CGRect {
        if theme == .polaroid {
            let paper = rect.insetBy(dx: 28, dy: 20)
            return CGRect(
                x: paper.minX + 38,
                y: paper.minY + 12,
                width: paper.width - 72,
                height: 104
            )
        }

        return rect.insetBy(dx: 26, dy: 24)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showInlineSettingsFromMenu), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let expandTitle = state.widget.isExpanded ? "Collapse Widget" : "Expand Widget"
        let expandItem = NSMenuItem(title: expandTitle, action: #selector(toggleExpandedFromMenu), keyEquivalent: "")
        expandItem.target = self
        menu.addItem(expandItem)

        if state.cover.isEnabled {
            let blurTitle = isEffectivelyBlurred(state) ? "Show Content" : "Hide Content"
            let blurItem = NSMenuItem(title: blurTitle, action: #selector(toggleBlurredFromMenu), keyEquivalent: "")
            blurItem.target = self
            menu.addItem(blurItem)
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Murmur", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if isShowingInlineSettings, settingsPanel.frame.contains(point) {
            settingsScrollView.scrollWheel(with: event)
            return
        }

        super.scrollWheel(with: event)
    }

    override func layout() {
        super.layout()
        let petSize = CGSize(width: 120, height: 120)

        if state.widget.isExpanded {
            let cardInset: CGFloat = 20
            cardView.frame = CGRect(x: cardInset, y: 24, width: bounds.width - cardInset * 2, height: 390)
            themeBackgroundView.frame = cardView.bounds
            coverView.frame = cardView.bounds
            contentStack.frame = contentFrame(for: state.widget.theme.style, in: cardView.bounds)
            settingsPanel.frame = cardView.bounds.insetBy(dx: 16, dy: 16)

            switch state.pet.edge {
            case .topRight:
                petView.frame = CGRect(x: cardView.frame.maxX - 92, y: cardView.frame.maxY - 44, width: petSize.width, height: petSize.height)
            case .topLeft:
                petView.frame = CGRect(x: cardView.frame.minX - 20, y: cardView.frame.maxY - 44, width: petSize.width, height: petSize.height)
            case .bottomRight:
                petView.frame = CGRect(x: cardView.frame.maxX - 96, y: cardView.frame.minY - 54, width: petSize.width, height: petSize.height)
            }
        } else {
            cardView.frame = .zero
            themeBackgroundView.frame = .zero
            coverView.frame = .zero
            contentStack.frame = .zero
            settingsPanel.frame = .zero
            railView.frame = .zero
            railGripView.frame = .zero
            railLabel.frame = .zero
            petView.frame = CGRect(
                x: (bounds.width - petSize.width) / 2,
                y: (bounds.height - petSize.height) / 2,
                width: petSize.width,
                height: petSize.height
            )
        }
    }

    func apply(_ newState: MurmurState, animated: Bool = true) {
        state = newState
        rebuildContent()
        themeBackgroundView.apply(newState.widget.theme)
        coverView.apply(cover: newState.cover, theme: newState.widget.theme)
        petView.apply(newState.pet)
        let effectivelyBlurred = isEffectivelyBlurred(newState)

        cardView.layer?.cornerRadius = CGFloat(newState.widget.theme.cornerRadius)
        coverView.layer?.cornerRadius = CGFloat(newState.widget.theme.cornerRadius)
        themeBackgroundView.layer?.cornerRadius = CGFloat(newState.widget.theme.cornerRadius)
        cardView.alphaValue = newState.widget.theme.style == .magazine
            ? CGFloat(newState.widget.theme.transparency)
            : 0.98
        cardView.isHidden = !newState.widget.isExpanded
        railView.isHidden = true
        railGripView.isHidden = true
        railLabel.isHidden = true
        settingsPanel.isHidden = !newState.widget.isExpanded || !isShowingInlineSettings

        let coverAlpha = effectivelyBlurred ? 1.0 : 0.0
        let contentAlpha = effectivelyBlurred ? 0.0 : 1.0
        contentStack.isHidden = !newState.widget.isExpanded || isShowingInlineSettings
        coverView.isHidden = !newState.widget.isExpanded || isShowingInlineSettings
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                coverView.animator().alphaValue = coverAlpha
                contentStack.animator().alphaValue = contentAlpha
            } completionHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.coverView.isHidden = !newState.widget.isExpanded || !effectivelyBlurred || (self?.isShowingInlineSettings ?? false)
                    self?.contentStack.isHidden = !newState.widget.isExpanded || effectivelyBlurred || (self?.isShowingInlineSettings ?? false)
                }
            }
        } else {
            coverView.alphaValue = coverAlpha
            contentStack.alphaValue = contentAlpha
            coverView.isHidden = !newState.widget.isExpanded || !effectivelyBlurred || isShowingInlineSettings
            contentStack.isHidden = !newState.widget.isExpanded || effectivelyBlurred || isShowingInlineSettings
        }

        needsLayout = true
    }

    private func isEffectivelyBlurred(_ state: MurmurState) -> Bool {
        state.cover.isEnabled && state.widget.isBlurred
    }

    private func setupViews() {
        cardView.material = .underWindowBackground
        cardView.blendingMode = .behindWindow
        cardView.state = .active
        cardView.wantsLayer = true
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor
        cardView.layer?.shadowColor = NSColor.black.cgColor
        cardView.layer?.shadowOpacity = 0.16
        cardView.layer?.shadowRadius = 22
        cardView.layer?.shadowOffset = CGSize(width: 0, height: -10)
        addSubview(cardView)

        railView.material = .hudWindow
        railView.blendingMode = .behindWindow
        railView.state = .active
        railView.wantsLayer = true
        railView.layer?.cornerRadius = 24
        railView.layer?.borderWidth = 1
        railView.layer?.borderColor = NSColor.white.withAlphaComponent(0.30).cgColor
        railView.layer?.shadowColor = NSColor.black.cgColor
        railView.layer?.shadowOpacity = 0.14
        railView.layer?.shadowRadius = 18
        railView.layer?.shadowOffset = CGSize(width: 0, height: -8)
        addSubview(railView)

        railGripView.wantsLayer = true
        addSubview(railGripView)

        railLabel.alignment = .center
        railLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        railLabel.textColor = NSColor.labelColor.withAlphaComponent(0.58)
        railLabel.isEditable = false
        railLabel.isSelectable = false
        addSubview(railLabel)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.distribution = .gravityAreas
        themeBackgroundView.wantsLayer = true
        cardView.addSubview(themeBackgroundView)
        cardView.addSubview(contentStack)

        coverView.wantsLayer = true
        cardView.addSubview(coverView)
        setupInlineSettings()
        cardView.addSubview(settingsPanel)
        addSubview(petView)
    }

    func showInlineSettings() {
        if !isShowingInlineSettings {
            inlineOriginalState = state
        }

        isShowingInlineSettings = true
        inlineDraftState = state
        let draft = inlineDraftState ?? state

        inlinePhraseField.stringValue = draft.content.mainPhrase
        inlineNoteField.stringValue = draft.content.privateNote
        inlineCoverField.stringValue = draft.cover.text
        let themeIndex = WidgetTheme.allCases.firstIndex(of: draft.widget.theme.style) ?? 0
        inlineThemePopup.selectItem(at: themeIndex)
        updateThemeBackgroundControls(for: draft.widget.theme.style)
        inlineCoverModePopup.selectItem(at: draft.cover.mode == .text ? 0 : 1)
        inlinePetKindPopup.selectItem(at: draft.pet.kind == .builtIn ? 0 : 1)
        let poseIndex = PetPose.allCases.firstIndex(of: draft.pet.pose) ?? 0
        inlinePetPosePopup.selectItem(at: poseIndex)
        inlineShowPhraseCheckbox.state = draft.content.showMainPhrase ? .on : .off
        inlineShowNoteCheckbox.state = draft.content.showPrivateNote ? .on : .off
        inlineShowTasksCheckbox.state = draft.content.showTasks ? .on : .off
        inlineExpandedCheckbox.state = .on
        inlineBlurredCheckbox.state = draft.cover.isEnabled ? .on : .off
        rebuildInlineTaskRows()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self.inlinePhraseField)
        }

        if !state.widget.isExpanded {
            var nextState = state
            nextState.widget.isExpanded = true
            onChange?(nextState)
        } else {
            apply(state)
        }
    }

    private func rebuildContent() {
        contentStack.arrangedSubviews.forEach { view in
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if state.widget.theme.style == .polaroid {
            rebuildPolaroidContent()
            return
        }

        contentStack.orientation = .vertical
        contentStack.distribution = .gravityAreas
        let visibleTasks = state.content.showTasks ? Array(state.content.tasks.prefix(5)) : []
        let mainText = state.content.mainPhrase.isEmpty ? "Murmur" : state.content.mainPhrase
        let noteText = state.content.privateNote.isEmpty ? "A softer place for things I want to remember." : state.content.privateNote
        let sparseContent = visibleTasks.count <= 2
            && mainText.count <= 24
            && noteText.count <= 54

        contentStack.spacing = sparseContent ? 16 : 11
        contentStack.alignment = .leading

        var didAddContent = false

        if sparseContent {
            contentStack.addArrangedSubview(spacer(height: 10))
        }

        if state.content.showMainPhrase {
            let title = NSTextField(labelWithString: mainText)
            title.font = themeTitleFont(size: sparseContent ? 40 : 30)
            title.textColor = themePrimaryTextColor
            title.maximumNumberOfLines = sparseContent ? 2 : 3
            title.lineBreakMode = .byWordWrapping
            title.widthAnchor.constraint(equalToConstant: 410).isActive = true
            contentStack.addArrangedSubview(title)
            didAddContent = true
        }

        if state.content.showPrivateNote {
            let note = NSTextField(labelWithString: noteText)
            note.font = themeSecondaryFont(size: sparseContent ? 18 : 15)
            note.textColor = themeSecondaryTextColor
            note.maximumNumberOfLines = sparseContent ? 3 : 2
            note.lineBreakMode = .byWordWrapping
            note.widthAnchor.constraint(equalToConstant: 410).isActive = true
            contentStack.addArrangedSubview(note)
            didAddContent = true
        }

        if state.content.showTasks {
            let separator = NSBox()
            separator.boxType = .separator
            separator.alphaValue = state.widget.theme.style == .corkboard ? 0.45 : 0.72
            separator.widthAnchor.constraint(equalToConstant: 410).isActive = true
            contentStack.addArrangedSubview(separator)

            if state.content.tasks.isEmpty {
                let empty = NSTextField(labelWithString: "No tasks yet.")
                empty.font = .systemFont(ofSize: sparseContent ? 15 : 13, weight: .regular)
                empty.textColor = themeSecondaryTextColor
                contentStack.addArrangedSubview(empty)
            } else {
                for task in visibleTasks {
                    let button = FirstMouseButton(checkboxWithTitle: task.text, target: self, action: #selector(toggleTask(_:)))
                    button.identifier = NSUserInterfaceItemIdentifier(task.id.uuidString)
                    button.state = task.completed ? .on : .off
                    button.font = themeTaskFont(size: sparseContent ? 16 : 14)
                    button.contentTintColor = themeAccentColor
                    button.allowsMixedState = false
                    button.controlSize = sparseContent ? .large : .regular
                    button.sendAction(on: [.leftMouseUp])
                    button.widthAnchor.constraint(lessThanOrEqualToConstant: 410).isActive = true
                    contentStack.addArrangedSubview(button)
                }
            }
            didAddContent = true
        }

        if !didAddContent {
            let empty = NSTextField(labelWithString: "Everything is hidden. Open Settings to choose what to show.")
            empty.font = .systemFont(ofSize: 15, weight: .regular)
            empty.textColor = themeSecondaryTextColor
            empty.maximumNumberOfLines = 2
            empty.widthAnchor.constraint(equalToConstant: 410).isActive = true
            contentStack.addArrangedSubview(empty)
        }

        contentStack.addArrangedSubview(spacer(height: sparseContent ? 6 : 2))

        let hint = NSTextField(labelWithString: "Right-click or use menu bar for settings")
        hint.font = themeSecondaryFont(size: 11)
        hint.textColor = themeSecondaryTextColor.withAlphaComponent(0.68)
        contentStack.addArrangedSubview(hint)
    }

    private func rebuildPolaroidContent() {
        let visibleTasks = state.content.showTasks ? state.content.tasks : []
        let mainText = state.content.mainPhrase.isEmpty ? "Murmur" : state.content.mainPhrase
        let noteText = state.content.privateNote.isEmpty ? "Collect beautiful moments." : state.content.privateNote

        contentStack.orientation = .horizontal
        contentStack.alignment = .top
        contentStack.spacing = 12
        contentStack.distribution = .fill

        let captionStack = NSStackView()
        captionStack.orientation = .vertical
        captionStack.alignment = .leading
        captionStack.spacing = 3
        captionStack.widthAnchor.constraint(equalToConstant: 172).isActive = true

        var didAddContent = false
        if state.content.showMainPhrase {
            let title = NSTextField(labelWithString: mainText)
            title.font = themeTitleFont(size: mainText.count <= 14 ? 22 : 18)
            title.textColor = themePrimaryTextColor
            title.maximumNumberOfLines = 1
            title.lineBreakMode = .byTruncatingTail
            title.widthAnchor.constraint(equalToConstant: 172).isActive = true
            captionStack.addArrangedSubview(title)
            didAddContent = true
        }

        if state.content.showPrivateNote {
            let note = NSTextField(labelWithString: noteText)
            note.font = themeSecondaryFont(size: noteText.count <= 34 ? 15 : 13)
            note.textColor = themeSecondaryTextColor
            note.maximumNumberOfLines = 2
            note.lineBreakMode = .byWordWrapping
            note.widthAnchor.constraint(equalToConstant: 172).isActive = true
            captionStack.addArrangedSubview(note)
            didAddContent = true
        }

        let taskStack = NSStackView()
        taskStack.orientation = .vertical
        taskStack.alignment = .leading
        let taskMetrics = polaroidTaskMetrics(count: visibleTasks.count)
        taskStack.spacing = taskMetrics.spacing
        taskStack.widthAnchor.constraint(equalToConstant: 160).isActive = true

        if state.content.showTasks {
            for task in visibleTasks {
                let button = FirstMouseButton(checkboxWithTitle: task.text, target: self, action: #selector(toggleTask(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(task.id.uuidString)
                button.state = task.completed ? .on : .off
                button.font = themeTaskFont(size: taskMetrics.fontSize)
                button.contentTintColor = themeAccentColor
                button.allowsMixedState = false
                button.controlSize = .regular
                button.sendAction(on: [.leftMouseUp])
                button.widthAnchor.constraint(equalToConstant: 160).isActive = true
                button.heightAnchor.constraint(equalToConstant: taskMetrics.rowHeight).isActive = true
                taskStack.addArrangedSubview(button)
            }
            didAddContent = true
        }

        if !didAddContent {
            let empty = NSTextField(labelWithString: "Open Settings to choose what to show.")
            empty.font = themeSecondaryFont(size: 12)
            empty.textColor = themeSecondaryTextColor
            empty.widthAnchor.constraint(equalToConstant: 320).isActive = true
            captionStack.addArrangedSubview(empty)
        }

        contentStack.addArrangedSubview(captionStack)
        if state.content.showTasks, !visibleTasks.isEmpty {
            contentStack.addArrangedSubview(taskStack)
        }
    }

    private func polaroidTaskMetrics(count: Int) -> (fontSize: CGFloat, rowHeight: CGFloat, spacing: CGFloat) {
        switch count {
        case 0...3:
            return (15, 25, 4)
        case 4...5:
            return (12.5, 18, 1)
        case 6...7:
            return (10.5, 14, 0)
        default:
            return (9.5, 12, 0)
        }
    }

    @objc private func toggleTask(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue, let uuid = UUID(uuidString: id) else { return }
        var nextState = state
        guard let index = nextState.content.tasks.firstIndex(where: { $0.id == uuid }) else { return }
        let wasCompleted = nextState.content.tasks[index].completed
        nextState.content.tasks[index].completed = sender.state == .on
        nextState.content.tasks[index].updatedAt = Date()
        onChange?(nextState)
        if !wasCompleted && nextState.content.tasks[index].completed {
            petView.playInteraction(.cheer)
        }
    }

    private func handleContentTaskClick(at point: CGPoint) -> Bool {
        guard state.widget.isExpanded, !isEffectivelyBlurred(state), !isShowingInlineSettings else { return false }

        for button in contentTaskButtons(in: contentStack) {
            guard let id = button.identifier?.rawValue,
                  let uuid = UUID(uuidString: id),
                  view(button, containsRootPoint: point, padding: 12)
            else {
                continue
            }

            var nextState = state
            guard let index = nextState.content.tasks.firstIndex(where: { $0.id == uuid }) else { return false }
            let wasCompleted = nextState.content.tasks[index].completed
            nextState.content.tasks[index].completed.toggle()
            nextState.content.tasks[index].updatedAt = Date()
            onChange?(nextState)
            if !wasCompleted && nextState.content.tasks[index].completed {
                petView.playInteraction(.cheer)
            }
            return true
        }

        return false
    }

    private func contentTaskButtons(in view: NSView) -> [NSButton] {
        var buttons: [NSButton] = []
        for subview in view.subviews {
            if let button = subview as? NSButton, button.identifier?.rawValue != nil {
                buttons.append(button)
            }
            buttons.append(contentsOf: contentTaskButtons(in: subview))
        }
        return buttons
    }

    @objc private func showInlineSettingsFromMenu() {
        showInlineSettings()
    }

    @objc private func toggleExpandedFromMenu() {
        var nextState = state
        nextState.widget.isExpanded.toggle()
        onChange?(nextState)
    }

    @objc private func toggleBlurredFromMenu() {
        var nextState = state
        guard nextState.cover.isEnabled else {
            nextState.widget.isBlurred = false
            nextState.widget.isExpanded = true
            onChange?(nextState)
            return
        }

        nextState.widget.isBlurred.toggle()
        if !nextState.widget.isExpanded {
            nextState.widget.isExpanded = true
        }
        onChange?(nextState)
    }

    @objc private func quitFromMenu() {
        DispatchQueue.main.async { [weak self] in
            self?.onRequestQuit?()
        }
    }

    @objc private func saveInlineSettings() {
        var nextState = collectInlineSettings()
        if !nextState.cover.isEnabled {
            nextState.widget.isBlurred = false
        }
        inlineDraftState = nil
        inlineOriginalState = nil
        isShowingInlineSettings = false
        onChange?(nextState)
    }

    @objc private func closeInlineSettings() {
        let restoredState = inlineOriginalState ?? state
        inlineDraftState = nil
        inlineOriginalState = nil
        isShowingInlineSettings = false
        onChange?(restoredState)
    }

    @objc private func quitFromInlineSettings() {
        onRequestQuit?()
    }

    @objc private func noopInlineToggle(_ sender: NSButton) {
    }

    @objc private func chooseInlineCoverImage() {
        var nextState = collectInlineSettings()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let path = panel.url?.path else {
            return
        }

        nextState.cover.mode = .image
        nextState.cover.imagePath = path
        inlineDraftState = nextState
        inlineCoverModePopup.selectItem(at: 1)
    }

    @objc private func clearInlineCoverImage() {
        var nextState = collectInlineSettings()
        nextState.cover.imagePath = nil
        nextState.cover.mode = .text
        inlineDraftState = nextState
        inlineCoverModePopup.selectItem(at: 0)
    }

    @objc private func chooseInlineCoverBackgroundImage() {
        var nextState = collectInlineSettings()
        guard nextState.widget.theme.style.allowsCustomBackground else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let path = panel.url?.path else {
            return
        }

        nextState.widget.theme.backgroundImagePath = path
        inlineDraftState = nextState
    }

    @objc private func clearInlineCoverBackgroundImage() {
        var nextState = collectInlineSettings()
        nextState.widget.theme.backgroundImagePath = nil
        inlineDraftState = nextState
    }

    @objc private func updateInlineThemePreview() {
        var nextState = collectInlineSettings()
        updateThemeBackgroundControls(for: nextState.widget.theme.style)
        if !nextState.widget.theme.style.allowsCustomBackground {
            nextState.widget.theme.backgroundImagePath = nil
        }
        inlineDraftState = nextState
    }

    private func updateThemeBackgroundControls(for theme: WidgetTheme) {
        let enabled = theme.allowsCustomBackground
        inlineUploadCoverBackgroundButton?.isEnabled = enabled
        inlineClearCoverBackgroundButton?.isEnabled = enabled
        if theme == .polaroid {
            inlineUploadCoverBackgroundButton?.title = "更换拍立得照片"
            inlineClearCoverBackgroundButton?.title = "清除拍立得照片"
        } else {
            inlineUploadCoverBackgroundButton?.title = "更换主题背景"
            inlineClearCoverBackgroundButton?.title = "清除主题背景"
        }
        let hint = theme == .polaroid
            ? "拍立得主题会把图片放进中央相片区"
            : (enabled ? "为当前主题更换背景图片" : "牛皮纸主题使用固定纸纹")
        inlineUploadCoverBackgroundButton?.toolTip = hint
        inlineClearCoverBackgroundButton?.toolTip = hint
    }

    @objc private func chooseInlinePetImage() {
        var nextState = collectInlineSettings()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let path = panel.url?.path else {
            return
        }

        nextState.pet.kind = .customImage
        nextState.pet.imagePath = path
        inlineDraftState = nextState
        inlinePetKindPopup.selectItem(at: 1)
    }

    @objc private func clearInlinePetImage() {
        var nextState = collectInlineSettings()
        nextState.pet.kind = .builtIn
        nextState.pet.imagePath = nil
        inlineDraftState = nextState
        inlinePetKindPopup.selectItem(at: 0)
    }

    @objc private func updateInlinePetKindPreview() {
        let nextState = collectInlineSettings()
        inlineDraftState = nextState
    }

    @objc private func updateInlinePetPosePreview() {
        var nextState = collectInlineSettings()
        nextState.pet.kind = .builtIn
        nextState.pet.imagePath = nil
        inlinePetKindPopup.selectItem(at: 0)
        inlineDraftState = nextState
    }

    @objc private func addInlineTask() {
        var nextState = collectInlineSettings()
        nextState.content.tasks.append(TaskItem(text: "New to-do"))
        inlineDraftState = nextState
        rebuildInlineTaskRows()
    }

    @objc private func deleteInlineTask(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue, let id = UUID(uuidString: rawValue) else { return }
        var nextState = collectInlineSettings()
        nextState.content.tasks.removeAll { $0.id == id }
        inlineDraftState = nextState
        rebuildInlineTaskRows()
    }

    @objc private func deleteCompletedInlineTasks() {
        var nextState = collectInlineSettings()
        nextState.content.tasks.removeAll { $0.completed }
        inlineDraftState = nextState
        rebuildInlineTaskRows()
    }

    private func handleInlineSettingsFallbackClick(at point: CGPoint) -> Bool {
        guard let target = inlineClickTarget(at: point) else { return false }

        switch target {
        case .toggle(let checkbox):
            checkbox.state = checkbox.state == .on ? .off : .on
            inlineDraftState = collectInlineSettings()
            return true
        case .deleteTask(let id):
            var nextState = collectInlineSettings()
            nextState.content.tasks.removeAll { $0.id == id }
            inlineDraftState = nextState
            rebuildInlineTaskRows()
            return true
        case .textField(let field):
            window?.makeFirstResponder(field)
            field.selectText(nil)
            return true
        case .button(let button):
            button.performClick(nil)
            return true
        case .popup(let popup):
            popup.performClick(nil)
            return true
        }
    }

    private enum InlineClickTarget {
        case toggle(NSButton)
        case deleteTask(UUID)
        case textField(NSTextField)
        case button(NSButton)
        case popup(NSPopUpButton)
    }

    private func inlineClickTarget(at point: CGPoint) -> InlineClickTarget? {
        guard isShowingInlineSettings, settingsPanel.frame.contains(point) else { return nil }

        let popups = [inlineThemePopup, inlineCoverModePopup, inlinePetKindPopup, inlinePetPosePopup]
        for popup in popups where view(popup, containsRootPoint: point, padding: 0) {
            return .popup(popup)
        }

        let textFields = [inlinePhraseField, inlineNoteField, inlineCoverField] + Array(inlineTaskFields.values)
        for field in textFields {
            if view(field, containsRootPoint: point, padding: 14) {
                return .textField(field)
            }
        }

        let checkboxes = [
            inlineShowPhraseCheckbox,
            inlineShowNoteCheckbox,
            inlineShowTasksCheckbox,
            inlineExpandedCheckbox,
            inlineBlurredCheckbox
        ]

        for checkbox in checkboxes where view(checkbox, containsRootPoint: point, padding: 12) {
            return .toggle(checkbox)
        }

        for (_, checkbox) in inlineTaskChecks where view(checkbox, containsRootPoint: point, padding: 12) {
            return .toggle(checkbox)
        }

        for (id, button) in inlineTaskDeleteButtons where view(button, containsRootPoint: point, padding: 14) {
            return .deleteTask(id)
        }

        let buttons = [
            inlineUploadCoverButton,
            inlineClearCoverButton,
            inlineUploadCoverBackgroundButton,
            inlineClearCoverBackgroundButton,
            inlineAddTaskButton,
            inlineDeleteCompletedButton,
            inlineSaveButton,
            inlineCloseButton,
            inlineQuitButton,
            inlineUploadPetButton,
            inlineClearPetButton
        ].compactMap { $0 }

        for button in buttons where view(button, containsRootPoint: point, padding: 14) {
            return .button(button)
        }

        let nearbyPopups = popups.filter { view($0, containsRootPoint: point, padding: 10) }
        if let popup = nearbyPopups.min(by: {
            distanceSquared(from: point, to: $0) < distanceSquared(from: point, to: $1)
        }) {
            return .popup(popup)
        }

        return nil
    }

    private func view(_ view: NSView, containsRootPoint point: CGPoint, padding: CGFloat = 6) -> Bool {
        guard !view.isHidden, view.window != nil else { return false }
        let localPoint = convert(point, to: view)
        return view.bounds.insetBy(dx: -padding, dy: -padding).contains(localPoint)
    }

    private func distanceSquared(from point: CGPoint, to view: NSView) -> CGFloat {
        let rect = view.convert(view.bounds, to: self)
        let nearestX = min(max(point.x, rect.minX), rect.maxX)
        let nearestY = min(max(point.y, rect.minY), rect.maxY)
        let deltaX = point.x - nearestX
        let deltaY = point.y - nearestY
        return deltaX * deltaX + deltaY * deltaY
    }

    private func setupInlineSettings() {
        settingsPanel.material = .hudWindow
        settingsPanel.blendingMode = .behindWindow
        settingsPanel.state = .active
        settingsPanel.wantsLayer = true
        settingsPanel.layer?.cornerRadius = 18
        settingsPanel.layer?.masksToBounds = true
        settingsPanel.isHidden = true

        settingsScrollView.translatesAutoresizingMaskIntoConstraints = false
        settingsScrollView.drawsBackground = false
        settingsScrollView.borderType = .noBorder
        settingsScrollView.hasVerticalScroller = true
        settingsScrollView.autohidesScrollers = true
        settingsPanel.addSubview(settingsScrollView)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        settingsScrollView.documentView = stack

        NSLayoutConstraint.activate([
            settingsScrollView.leadingAnchor.constraint(equalTo: settingsPanel.leadingAnchor, constant: 18),
            settingsScrollView.trailingAnchor.constraint(equalTo: settingsPanel.trailingAnchor, constant: -18),
            settingsScrollView.topAnchor.constraint(equalTo: settingsPanel.topAnchor, constant: 16),
            settingsScrollView.bottomAnchor.constraint(equalTo: settingsPanel.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: settingsScrollView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: settingsScrollView.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: settingsScrollView.contentView.topAnchor),
            stack.widthAnchor.constraint(equalTo: settingsScrollView.contentView.widthAnchor)
        ])

        [inlinePhraseField, inlineNoteField, inlineCoverField].forEach { field in
            field.isEditable = true
            field.isSelectable = true
            field.isEnabled = true
            field.focusRingType = .default
        }

        [
            inlineShowPhraseCheckbox,
            inlineShowNoteCheckbox,
            inlineShowTasksCheckbox,
            inlineExpandedCheckbox,
            inlineBlurredCheckbox
        ].forEach { checkbox in
            checkbox.target = self
            checkbox.action = #selector(noopInlineToggle(_:))
            checkbox.isEnabled = true
            checkbox.allowsMixedState = false
        }

        inlineThemePopup.addItems(withTitles: WidgetTheme.allCases.map(Self.widgetThemeTitle))
        inlineThemePopup.isEnabled = true
        inlineThemePopup.target = self
        inlineThemePopup.action = #selector(updateInlineThemePreview)
        inlineCoverModePopup.addItems(withTitles: ["文字封面", "图片封面"])
        inlineCoverModePopup.isEnabled = true
        let uploadCoverButton = inlineButton("上传封面图片", action: #selector(chooseInlineCoverImage))
        let clearCoverButton = inlineButton("清除封面图片", action: #selector(clearInlineCoverImage))
        let uploadCoverBackgroundButton = inlineButton("更换主题背景", action: #selector(chooseInlineCoverBackgroundImage))
        let clearCoverBackgroundButton = inlineButton("清除主题背景", action: #selector(clearInlineCoverBackgroundImage))
        inlineUploadCoverButton = uploadCoverButton
        inlineClearCoverButton = clearCoverButton
        inlineUploadCoverBackgroundButton = uploadCoverBackgroundButton
        inlineClearCoverBackgroundButton = clearCoverBackgroundButton

        inlinePetKindPopup.addItems(withTitles: ["内置小猫", "自定义图片"])
        inlinePetKindPopup.isEnabled = true
        inlinePetKindPopup.target = self
        inlinePetKindPopup.action = #selector(updateInlinePetKindPreview)
        inlinePetPosePopup.addItems(withTitles: PetPose.allCases.map(Self.petPoseTitle))
        inlinePetPosePopup.isEnabled = true
        inlinePetPosePopup.target = self
        inlinePetPosePopup.action = #selector(updateInlinePetPosePreview)
        let uploadPetButton = inlineButton("上传桌宠图片", action: #selector(chooseInlinePetImage))
        let clearPetButton = inlineButton("恢复内置小猫", action: #selector(clearInlinePetImage))
        inlineUploadPetButton = uploadPetButton
        inlineClearPetButton = clearPetButton

        inlineTaskStack.orientation = .vertical
        inlineTaskStack.alignment = .leading
        inlineTaskStack.spacing = 8
        let addTaskButton = inlineButton("新增 to-do", action: #selector(addInlineTask))
        let deleteCompletedButton = inlineButton("删除已完成", action: #selector(deleteCompletedInlineTasks))
        inlineAddTaskButton = addTaskButton
        inlineDeleteCompletedButton = deleteCompletedButton

        let saveButton = inlineButton("保存", action: #selector(saveInlineSettings))
        let closeButton = inlineButton("关闭", action: #selector(closeInlineSettings))
        let quitButton = inlineButton("退出 Murmur", action: #selector(quitFromInlineSettings))
        inlineSaveButton = saveButton
        inlineCloseButton = closeButton
        inlineQuitButton = quitButton

        stack.addArrangedSubview(settingsHeader())
        stack.addArrangedSubview(settingsSection(
            title: "Content",
            subtitle: "选择组件里要展示的文字和 to-do。",
            arrangedSubviews: [
                inlineShowPhraseCheckbox,
                inlineRow("主文案", inlinePhraseField),
                inlineShowNoteCheckbox,
                inlineRow("碎碎念", inlineNoteField),
                inlineShowTasksCheckbox,
                inlineTaskStack,
                inlineButtonRow([addTaskButton, deleteCompletedButton])
            ]
        ))
        stack.addArrangedSubview(settingsSection(
            title: "Theme",
            subtitle: "主题决定整个组件的框体、排版与材质。牛皮纸使用固定纸纹。",
            arrangedSubviews: [
                inlineRow("组件主题", inlineThemePopup),
                inlineButtonRow([uploadCoverBackgroundButton, clearCoverBackgroundButton])
            ]
        ))
        stack.addArrangedSubview(settingsSection(
            title: "Cover",
            subtitle: "设置模糊封面中央显示的文字或图片。",
            arrangedSubviews: [
                inlineRow("封面类型", inlineCoverModePopup),
                inlineRow("封面文案", inlineCoverField),
                inlineButtonRow([uploadCoverButton, clearCoverButton]),
                inlineBlurredCheckbox,
                inlineExpandedCheckbox
            ]
        ))
        stack.addArrangedSubview(settingsSection(
            title: "Pet",
            subtitle: "选择边缘桌宠，后续可以继续升级动态姿态。",
            arrangedSubviews: [
                inlineRow("桌宠类型", inlinePetKindPopup),
                inlineRow("小猫姿态", inlinePetPosePopup),
                inlineButtonRow([uploadPetButton, clearPetButton])
            ]
        ))
        stack.addArrangedSubview(settingsActionRow(save: saveButton, close: closeButton, quit: quitButton))
    }

    private func inlineButton(_ title: String, action: Selector) -> NSButton {
        let button = FirstMouseButton(title: title, target: self, action: action)
        button.isEnabled = true
        button.sendAction(on: [.leftMouseUp])
        button.bezelStyle = .rounded
        button.controlSize = .large
        return button
    }

    private func displayFont(ofSize size: CGFloat, weight: NSFont.Weight = .semibold) -> NSFont {
        let preferredNames = [
            "NewYork-Regular",
            "New York",
            "Baskerville-SemiBold",
            "Baskerville",
            "Didot"
        ]

        for name in preferredNames {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }

        return .systemFont(ofSize: size, weight: weight)
    }

    private var themePrimaryTextColor: NSColor {
        switch state.widget.theme.style {
        case .corkboard:
            return NSColor.white.withAlphaComponent(0.94)
        case .kraft:
            return NSColor(calibratedRed: 0.14, green: 0.09, blue: 0.05, alpha: 0.92)
        case .polaroid:
            return NSColor(calibratedRed: 0.13, green: 0.11, blue: 0.09, alpha: 0.92)
        default:
            return NSColor.labelColor.withAlphaComponent(0.94)
        }
    }

    private var themeSecondaryTextColor: NSColor {
        switch state.widget.theme.style {
        case .corkboard:
            return NSColor.white.withAlphaComponent(0.74)
        case .kraft:
            return NSColor(calibratedRed: 0.16, green: 0.10, blue: 0.06, alpha: 0.72)
        case .polaroid:
            return NSColor(calibratedRed: 0.22, green: 0.18, blue: 0.14, alpha: 0.70)
        case .collage:
            return NSColor(calibratedRed: 0.22, green: 0.18, blue: 0.15, alpha: 0.68)
        default:
            return NSColor.labelColor.withAlphaComponent(0.64)
        }
    }

    private var themeAccentColor: NSColor {
        switch state.widget.theme.style {
        case .kraft:
            return NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.10, alpha: 0.90)
        case .polaroid:
            return NSColor(calibratedRed: 0.50, green: 0.38, blue: 0.30, alpha: 0.96)
        case .collage:
            return NSColor(calibratedRed: 0.52, green: 0.38, blue: 0.26, alpha: 0.96)
        case .corkboard:
            return NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.35, alpha: 0.96)
        case .magazine:
            return NSColor.controlAccentColor
        }
    }

    private func themeTitleFont(size: CGFloat) -> NSFont {
        switch state.widget.theme.style {
        case .magazine:
            return displayFont(ofSize: size, weight: .bold)
        case .kraft:
            return NSFont(name: "Courier-Bold", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .bold)
        case .polaroid:
            return NSFont(name: "AvenirNext-Heavy", size: size)
                ?? NSFont(name: "ArialRoundedMTBold", size: size)
                ?? .systemFont(ofSize: size, weight: .heavy)
        case .collage:
            return NSFont(name: "Noteworthy-Bold", size: size) ?? displayFont(ofSize: size, weight: .bold)
        case .corkboard:
            return NSFont(name: "AvenirNext-DemiBold", size: size) ?? .systemFont(ofSize: size, weight: .bold)
        }
    }

    private func themeSecondaryFont(size: CGFloat) -> NSFont {
        switch state.widget.theme.style {
        case .kraft:
            return NSFont(name: "Courier", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        case .polaroid:
            return NSFont(name: "BradleyHandITCTT-Bold", size: size)
                ?? NSFont(name: "Noteworthy-Light", size: size)
                ?? .systemFont(ofSize: size, weight: .medium)
        case .collage:
            return NSFont(name: "Noteworthy-Light", size: size) ?? .systemFont(ofSize: size, weight: .medium)
        default:
            return .systemFont(ofSize: size, weight: .medium)
        }
    }

    private func themeTaskFont(size: CGFloat) -> NSFont {
        switch state.widget.theme.style {
        case .kraft:
            return NSFont(name: "Courier", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        case .polaroid:
            return NSFont(name: "AvenirNext-Medium", size: size) ?? .systemFont(ofSize: size, weight: .medium)
        case .collage:
            return NSFont(name: "Noteworthy", size: size) ?? .systemFont(ofSize: size, weight: .regular)
        default:
            return .systemFont(ofSize: size, weight: .regular)
        }
    }

    private func spacer(height: CGFloat) -> NSView {
        let view = NSView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func settingsHeader() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2

        let title = NSTextField(labelWithString: "Murmur Settings")
        title.font = displayFont(ofSize: 30, weight: .bold)
        title.textColor = NSColor.labelColor.withAlphaComponent(0.95)

        let subtitle = NSTextField(labelWithString: "Make this little corner yours.")
        subtitle.font = .systemFont(ofSize: 12, weight: .medium)
        subtitle.textColor = NSColor.secondaryLabelColor

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        return stack
    }

    private func settingsSection(title: String, subtitle: String, arrangedSubviews: [NSView]) -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 9
        section.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 14, right: 14)
        section.wantsLayer = true
        section.layer?.cornerRadius = 16
        section.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor
        section.layer?.borderWidth = 1
        section.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = NSColor.labelColor.withAlphaComponent(0.86)

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.widthAnchor.constraint(equalToConstant: 360).isActive = true

        section.addArrangedSubview(titleLabel)
        section.addArrangedSubview(subtitleLabel)
        section.addArrangedSubview(spacer(height: 2))

        for view in arrangedSubviews {
            section.addArrangedSubview(view)
        }

        section.widthAnchor.constraint(equalToConstant: 390).isActive = true
        return section
    }

    private func settingsActionRow(save: NSButton, close: NSButton, quit: NSButton) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 2, bottom: 4, right: 2)

        save.font = .systemFont(ofSize: 13, weight: .semibold)
        close.font = .systemFont(ofSize: 13, weight: .medium)
        quit.font = .systemFont(ofSize: 13, weight: .medium)

        stack.addArrangedSubview(save)
        stack.addArrangedSubview(close)
        stack.addArrangedSubview(quit)
        return stack
    }

    private func inlineRow(_ label: String, _ field: NSTextField) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8

        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 12, weight: .semibold)
        labelView.textColor = NSColor.labelColor.withAlphaComponent(0.72)
        labelView.widthAnchor.constraint(equalToConstant: 72).isActive = true

        field.widthAnchor.constraint(equalToConstant: 250).isActive = true
        field.controlSize = .large
        field.font = .systemFont(ofSize: 13, weight: .regular)
        stack.addArrangedSubview(labelView)
        stack.addArrangedSubview(field)
        return stack
    }

    private func inlineRow(_ label: String, _ control: NSView) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8

        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 12, weight: .semibold)
        labelView.textColor = NSColor.labelColor.withAlphaComponent(0.72)
        labelView.widthAnchor.constraint(equalToConstant: 72).isActive = true

        control.widthAnchor.constraint(equalToConstant: 250).isActive = true
        stack.addArrangedSubview(labelView)
        stack.addArrangedSubview(control)
        return stack
    }

    private func inlineButtonRow(_ buttons: [NSButton]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8

        for button in buttons {
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.isEnabled = true
            stack.addArrangedSubview(button)
        }

        return stack
    }

    private func rebuildInlineTaskRows() {
        inlineTaskStack.arrangedSubviews.forEach { view in
            inlineTaskStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        inlineTaskFields.removeAll()
        inlineTaskChecks.removeAll()
        inlineTaskDeleteButtons.removeAll()

        let workingState = inlineDraftState ?? state

        if workingState.content.tasks.isEmpty {
            let empty = NSTextField(labelWithString: "暂无 to-do，点击“新增 to-do”。")
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = .secondaryLabelColor
            inlineTaskStack.addArrangedSubview(empty)
            return
        }

        for task in workingState.content.tasks {
            inlineTaskStack.addArrangedSubview(inlineTaskRow(task))
        }
    }

    private func inlineTaskRow(_ task: TaskItem) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6

        let checkbox = FirstMouseButton(checkboxWithTitle: "", target: self, action: #selector(noopInlineToggle(_:)))
        checkbox.state = task.completed ? .on : .off
        checkbox.isEnabled = true
        checkbox.allowsMixedState = false
        checkbox.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let field = FirstMouseTextField()
        field.stringValue = task.text
        field.isEditable = true
        field.isSelectable = true
        field.isEnabled = true
        field.focusRingType = .default
        field.widthAnchor.constraint(equalToConstant: 230).isActive = true

        let deleteButton = inlineButton("删", action: #selector(deleteInlineTask(_:)))
        deleteButton.identifier = NSUserInterfaceItemIdentifier(task.id.uuidString)
        deleteButton.bezelStyle = .rounded

        inlineTaskChecks[task.id] = checkbox
        inlineTaskFields[task.id] = field
        inlineTaskDeleteButtons[task.id] = deleteButton

        stack.addArrangedSubview(checkbox)
        stack.addArrangedSubview(field)
        stack.addArrangedSubview(deleteButton)
        return stack
    }

    private func collectInlineSettings() -> MurmurState {
        var nextState = inlineDraftState ?? state
        nextState.content.mainPhrase = inlinePhraseField.stringValue
        nextState.content.privateNote = inlineNoteField.stringValue
        nextState.content.showMainPhrase = inlineShowPhraseCheckbox.state == .on
        nextState.content.showPrivateNote = inlineShowNoteCheckbox.state == .on
        nextState.content.showTasks = inlineShowTasksCheckbox.state == .on
        nextState.cover.isEnabled = inlineBlurredCheckbox.state == .on
        let themeIndex = max(0, inlineThemePopup.indexOfSelectedItem)
        if WidgetTheme.allCases.indices.contains(themeIndex) {
            nextState.widget.theme.style = WidgetTheme.allCases[themeIndex]
            if !nextState.widget.theme.style.allowsCustomBackground {
                nextState.widget.theme.backgroundImagePath = nil
            }
        }
        nextState.cover.text = inlineCoverField.stringValue
        nextState.cover.mode = inlineCoverModePopup.indexOfSelectedItem == 0 ? .text : .image
        nextState.pet.kind = inlinePetKindPopup.indexOfSelectedItem == 0 ? .builtIn : .customImage
        let poseIndex = max(0, inlinePetPosePopup.indexOfSelectedItem)
        if PetPose.allCases.indices.contains(poseIndex) {
            nextState.pet.pose = PetPose.allCases[poseIndex]
        }
        nextState.widget.isExpanded = inlineExpandedCheckbox.state == .on
        nextState.widget.isBlurred = nextState.cover.isEnabled

        for index in nextState.content.tasks.indices {
            let id = nextState.content.tasks[index].id
            nextState.content.tasks[index].text = inlineTaskFields[id]?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? nextState.content.tasks[index].text
            nextState.content.tasks[index].completed = inlineTaskChecks[id]?.state == .on
            nextState.content.tasks[index].updatedAt = Date()
        }
        nextState.content.tasks.removeAll { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return nextState
    }

    private static func petPoseTitle(_ pose: PetPose) -> String {
        switch pose {
        case .catDefault:
            return "默认"
        case .catSit:
            return "打招呼"
        case .catSleep:
            return "睡觉"
        case .catYarn:
            return "玩毛线"
        case .catBox:
            return "纸箱"
        case .catCookie:
            return "吃饼干"
        }
    }

    private static func widgetThemeTitle(_ theme: WidgetTheme) -> String {
        switch theme {
        case .magazine:
            return "杂志风"
        case .kraft:
            return "牛皮纸"
        case .polaroid:
            return "拍立得"
        case .collage:
            return "拼贴手帐"
        case .corkboard:
            return "软木照片墙"
        }
    }
}

final class RailGripView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.labelColor.withAlphaComponent(0.26).setFill()
        for index in 0..<3 {
            let y = bounds.maxY - CGFloat(index + 1) * 8
            NSBezierPath(ovalIn: CGRect(x: bounds.midX - 2, y: y, width: 4, height: 4)).fill()
        }
    }
}

final class FirstMouseButton: NSButton {
    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func scrollWheel(with event: NSEvent) {
        murmurEnclosingScrollView?.scrollWheel(with: event) ?? super.scrollWheel(with: event)
    }
}

final class FirstMouseTextField: NSTextField {
    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func scrollWheel(with event: NSEvent) {
        murmurEnclosingScrollView?.scrollWheel(with: event) ?? super.scrollWheel(with: event)
    }
}

final class FirstMousePopUpButton: NSPopUpButton {
    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func scrollWheel(with event: NSEvent) {
        murmurEnclosingScrollView?.scrollWheel(with: event) ?? super.scrollWheel(with: event)
    }
}

private extension NSView {
    var murmurEnclosingScrollView: NSScrollView? {
        var currentView = superview
        while let view = currentView {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            currentView = view.superview
        }
        return nil
    }
}
