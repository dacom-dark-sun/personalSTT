import AppKit
import AVFoundation

final class AppController: NSObject, NSApplicationDelegate {
    private let config = Config.load()
    private let audio = AudioCapture()
    private let overlay = RecordingOverlay()
    private lazy var transcriber = Transcriber(config: config)
    private lazy var hotkey = Hotkey(spec: config.hotkey)

    private var statusItem: NSStatusItem!
    private var busy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenu()
        requestMicPermission()

        hotkey.onPress = { [weak self] in self?.startRecording() }
        hotkey.onRelease = { [weak self] in self?.stopAndTranscribe() }
        hotkey.start()

        if config.apiKey.isEmpty {
            notify(title: "personal-stt",
                   body: "OPENAI_API_KEY not set. Export it or put it in ~/.config/personal-stt/config.json")
        }
    }

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.title = "🎙"
            btn.toolTip = "personal-stt — hold hotkey to dictate"
            btn.target = self
            btn.action = #selector(statusItemClicked)
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Hold hotkey to record", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self
        statusItem.menu = menu
    }

    @objc private func statusItemClicked() {
        // Click opens menu (already wired).
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async { [weak self] in
                    self?.notify(title: "personal-stt",
                                 body: "Microphone access denied. Enable in System Settings → Privacy.")
                }
            }
        }
    }

    private func startRecording() {
        guard !busy, !audio.isRecording else { return }
        do {
            try audio.start()
            Sounds.start()
            overlay.show()
        } catch {
            Sounds.error()
            notify(title: "personal-stt", body: "Recording failed: \(error.localizedDescription)")
        }
    }

    private func stopAndTranscribe() {
        guard audio.isRecording else { return }
        let wav = audio.stop()
        Sounds.stop()
        overlay.hide()

        guard let wav = wav, wav.count > 44 + 1600 else { return } // ignore <~50 ms

        busy = true
        Task {
            defer { self.busy = false }
            do {
                let text = try await self.transcriber.transcribe(wav: wav)
                guard !text.isEmpty else { return }
                await MainActor.run { TextInjector.insert(text) }
            } catch {
                await MainActor.run {
                    Sounds.error()
                    self.notify(title: "personal-stt", body: "Whisper: \(error.localizedDescription)")
                }
            }
        }
    }

    private func notify(title: String, body: String) {
        let n = NSUserNotification()
        n.title = title
        n.informativeText = body
        NSUserNotificationCenter.default.deliver(n)
    }
}

// Entry point
let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.run()
