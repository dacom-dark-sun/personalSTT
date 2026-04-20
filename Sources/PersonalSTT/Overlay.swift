import AppKit

/// Floating borderless window on top of everything with a pulsing red dot + elapsed timer.
/// Not clickable, not focusable — purely informational.
final class RecordingOverlay {
    private var window: NSWindow?
    private var timerLabel: NSTextField?
    private var dot: NSView?
    private var startTime: Date?
    private var tickTimer: Timer?
    private var pulse: CABasicAnimation?

    func show() {
        DispatchQueue.main.async { [weak self] in self?._show() }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in self?._hide() }
    }

    private func _show() {
        _hide()

        let width: CGFloat = 160
        let height: CGFloat = 44
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = screen.frame
        let origin = NSPoint(
            x: frame.midX - width / 2,
            y: frame.maxY - height - 16
        )

        let win = NSWindow(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        win.ignoresMouseEvents = true
        win.hasShadow = true

        let root = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.72).cgColor
        root.layer?.cornerRadius = 12

        let dotSize: CGFloat = 12
        let dotView = NSView(frame: NSRect(x: 14, y: (height - dotSize) / 2, width: dotSize, height: dotSize))
        dotView.wantsLayer = true
        dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        dotView.layer?.cornerRadius = dotSize / 2
        root.addSubview(dotView)

        let pulseAnim = CABasicAnimation(keyPath: "opacity")
        pulseAnim.fromValue = 1.0
        pulseAnim.toValue = 0.25
        pulseAnim.duration = 0.7
        pulseAnim.autoreverses = true
        pulseAnim.repeatCount = .infinity
        dotView.layer?.add(pulseAnim, forKey: "pulse")
        self.pulse = pulseAnim

        let label = NSTextField(frame: NSRect(x: 36, y: 0, width: width - 48, height: height))
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.textColor = .white
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.alignment = .left
        label.stringValue = "● REC  00:00"
        root.addSubview(label)

        win.contentView = root
        win.orderFrontRegardless()

        self.window = win
        self.timerLabel = label
        self.dot = dotView
        self.startTime = Date()

        self.tickTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        RunLoop.main.add(self.tickTimer!, forMode: .common)
    }

    private func updateTimer() {
        guard let start = startTime, let label = timerLabel else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let m = elapsed / 60
        let s = elapsed % 60
        label.stringValue = String(format: "● REC  %02d:%02d", m, s)
    }

    private func _hide() {
        tickTimer?.invalidate()
        tickTimer = nil
        window?.orderOut(nil)
        window = nil
        timerLabel = nil
        dot = nil
        startTime = nil
    }
}
