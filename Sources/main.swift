import AppKit
import UniformTypeIdentifiers

final class CropCanvas: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    var image: CGImage? { didSet { selection = nil; needsDisplay = true } }
    var selection: CGRect?
    private var start: CGPoint?
    var didSelect: ((CGRect) -> Void)?
    var selectionChanged: ((String) -> Void)?

    var imageRect: CGRect {
        guard let image else { return .zero }
        let scale = min(max(1, bounds.width - 48) / CGFloat(image.width), max(1, bounds.height - 48) / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
    }
    override func resetCursorRects() {
        super.resetCursorRects()
        if image != nil { addCursorRect(imageRect, cursor: .crosshair) }
    }
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        selection = nil
        start = nil
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.095, alpha: 1).setFill()
        bounds.fill()
        guard let image else {
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 19, weight: .medium), .foregroundColor: NSColor(calibratedWhite: 0.7, alpha: 1)]
            let message = "打开一张图片，然后拖动框选"
            let size = (message as NSString).size(withAttributes: attributes)
            (message as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
            return
        }
        let target = imageRect
        NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)).draw(in: target, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        if let selected = selection, selected.width > 0, selected.height > 0 {
            let mask = NSBezierPath(rect: target)
            mask.appendRect(selected)
            mask.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.48).setFill()
            mask.fill()
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selected)
            border.lineWidth = 1.5
            border.stroke()
            for point in [CGPoint(x: selected.minX, y: selected.minY), CGPoint(x: selected.maxX, y: selected.minY), CGPoint(x: selected.minX, y: selected.maxY), CGPoint(x: selected.maxX, y: selected.maxY)] {
                NSColor.controlAccentColor.setFill()
                NSBezierPath(roundedRect: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6), xRadius: 1, yRadius: 1).fill()
            }
        }
    }
    private func clamped(_ point: CGPoint) -> CGPoint {
        let rect = imageRect
        return CGPoint(x: min(rect.maxX, max(rect.minX, point.x)), y: min(rect.maxY, max(rect.minY, point.y)))
    }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard image != nil, imageRect.contains(point) else { return }
        window?.makeFirstResponder(self)
        start = clamped(point)
        selection = nil
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start, let image else { return }
        let end = clamped(convert(event.locationInWindow, from: nil))
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
        selection = rect
        if let pixels = try? CropEngine.pixelRect(selection: rect, displayedImage: imageRect, width: image.width, height: image.height) {
            selectionChanged?("框选：\(Int(pixels.width)) × \(Int(pixels.height)) 像素 · 松开鼠标自动保存")
        }
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        guard start != nil else { return }
        mouseDragged(with: event)
        start = nil
        guard let selected = selection, selected.width >= 3, selected.height >= 3, let image else {
            selection = nil
            selectionChanged?("请拖动框选至少 3 × 3 屏幕点的区域。")
            needsDisplay = true
            return
        }
        if let pixels = try? CropEngine.pixelRect(selection: selected, displayedImage: imageRect, width: image.width, height: image.height) {
            didSelect?(pixels)
        }
    }
    override func cancelOperation(_ sender: Any?) {
        start = nil
        selection = nil
        needsDisplay = true
        selectionChanged?("已取消选区。拖动框选，松开鼠标自动保存。")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let canvas = CropCanvas()
    let imageLabel = NSTextField(labelWithString: "尚未打开图片")
    let dimensionsLabel = NSTextField(labelWithString: "")
    let folderLabel = NSTextField(labelWithString: "默认保存到原图旁的“逐图截图”文件夹")
    let statusLabel = NSTextField(labelWithString: "原图保持不变 · 截图按原始像素保存为 PNG")
    let countLabel = NSTextField(labelWithString: "已保存 0 张")
    var outputButton: NSButton!
    var revealButton: NSButton!
    var sourceURL: URL?
    var customDirectory: URL?
    var lastSavedURL: URL?
    var count = 0
    var saveInProgress = false

    var outputDirectory: URL? {
        customDirectory ?? sourceURL?.deletingLastPathComponent().appendingPathComponent("逐图截图", isDirectory: true)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        canvas.didSelect = { [weak self] in self?.saveCrop($0) }
        canvas.selectionChanged = { [weak self] in self?.statusLabel.stringValue = $0 }
        // Optional path argument is useful for launching with a known image.
        if let path = CommandLine.arguments.dropFirst().first, !path.hasPrefix("-") {
            loadImage(URL(fileURLWithPath: path))
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        guard window != nil else { return false }
        loadImage(URL(fileURLWithPath: filename))
        return true
    }
    func button(_ title: String, _ selector: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: selector)
        b.bezelStyle = .rounded
        return b
    }
    func stack(_ views: [NSView], spacing: CGFloat = 12) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.alignment = .centerY
        s.spacing = spacing
        return s
    }
    func buildMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        menu.addItem(appItem)
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "退出 图片随手裁", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let fileItem = NSMenuItem()
        menu.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件")
        fileItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "打开图片…", action: #selector(openImage), keyEquivalent: "o").target = self
        let folder = fileMenu.addItem(withTitle: "选择保存文件夹…", action: #selector(chooseDirectory), keyEquivalent: "s")
        folder.keyEquivalentModifierMask = [.command, .shift]
        folder.target = self
        fileMenu.addItem(withTitle: "打开保存位置", action: #selector(openOutput), keyEquivalent: "l").target = self
        let viewItem = NSMenuItem()
        menu.addItem(viewItem)
        let viewMenu = NSMenu(title: "视图")
        viewItem.submenu = viewMenu
        let full = viewMenu.addItem(withTitle: "切换全屏", action: #selector(toggleFullScreen), keyEquivalent: "f")
        full.keyEquivalentModifierMask = [.command, .control]
        full.target = self
        NSApp.mainMenu = menu
    }
    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 850), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "图片随手裁"
        window.minSize = NSSize(width: 800, height: 580)
        window.isReleasedWhenClosed = false
        let root = NSView()
        window.contentView = root
        let open = button("打开图片…", #selector(openImage))
        open.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        open.imagePosition = .imageLeading
        open.bezelColor = .controlAccentColor
        let directory = button("选择保存文件夹…", #selector(chooseDirectory))
        outputButton = button("打开保存位置", #selector(openOutput))
        outputButton.isEnabled = false
        let top = stack([open, directory, outputButton, NSView(), countLabel])
        countLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        imageLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        imageLabel.lineBreakMode = .byTruncatingMiddle
        imageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        dimensionsLabel.textColor = .secondaryLabelColor
        let info = stack([imageLabel, NSView(), dimensionsLabel])
        let instruction = NSTextField(labelWithString: "拖动框选 → 松开鼠标 → 自动保存    ·    可反复框选，Esc 清除选区")
        instruction.font = .systemFont(ofSize: 13, weight: .medium)
        canvas.wantsLayer = true
        canvas.layer?.cornerRadius = 14
        canvas.layer?.masksToBounds = true
        folderLabel.font = .systemFont(ofSize: 12)
        folderLabel.textColor = .secondaryLabelColor
        folderLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        revealButton = button("显示刚保存的图片", #selector(revealLast))
        revealButton.isEnabled = false
        let bottom = stack([statusLabel, NSView(), revealButton])
        let content = NSStackView(views: [top, info, instruction, canvas, folderLabel, bottom])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(content)
        for child in [top, info, instruction, canvas, folderLabel, bottom] {
            child.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
        canvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22)
        ])
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    @objc func openImage() {
        let panel = NSOpenPanel()
        panel.title = "打开需要截图的图片"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadImage(url)
    }
    func loadImage(_ url: URL) {
        do {
            let image = try CropEngine.load(url)
            sourceURL = url
            canvas.image = image
            imageLabel.stringValue = url.lastPathComponent
            imageLabel.toolTip = url.path
            dimensionsLabel.stringValue = "\(image.width) × \(image.height) 像素"
            lastSavedURL = nil
            count = 0
            countLabel.stringValue = "已保存 0 张"
            revealButton.isEnabled = false
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = "已打开图片。拖动框选，松开鼠标自动保存。"
            refreshFolder()
            window.makeFirstResponder(canvas)
            window.invalidateCursorRects(for: canvas)
        } catch { showError(error) }
    }
    @objc func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择截图自动保存的文件夹"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "设为保存位置"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        customDirectory = url
        refreshFolder()
        statusLabel.stringValue = "保存位置已设置。之后每次框选都会自动存到这里。"
    }
    func refreshFolder() {
        if let directory = outputDirectory {
            folderLabel.stringValue = "自动保存到：\(directory.path)"
            folderLabel.toolTip = directory.path
            outputButton.isEnabled = true
        }
    }
    func saveCrop(_ rect: CGRect) {
        guard !saveInProgress, let image = canvas.image, let sourceURL, let directory = outputDirectory else { return }
        saveInProgress = true
        defer { saveInProgress = false }
        do {
            let crop = try CropEngine.crop(image, rect: rect)
            let saved = try CropEngine.save(crop, directory: directory, stem: sourceURL.deletingPathExtension().lastPathComponent)
            lastSavedURL = saved
            count += 1
            countLabel.stringValue = "已保存 \(count) 张"
            statusLabel.textColor = .systemGreen
            statusLabel.stringValue = "已保存 \(crop.width) × \(crop.height)：\(saved.lastPathComponent)"
            statusLabel.toolTip = saved.path
            revealButton.isEnabled = true
        } catch { showError(error) }
    }
    @objc func openOutput() {
        guard let directory = outputDirectory else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(directory)
        } catch { showError(error) }
    }
    @objc func revealLast() {
        if let lastSavedURL { NSWorkspace.shared.activateFileViewerSelecting([lastSavedURL]) }
    }
    @objc func toggleFullScreen() { window.toggleFullScreen(nil) }
    func showError(_ error: Error) {
        statusLabel.textColor = .systemRed
        statusLabel.stringValue = error.localizedDescription
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
