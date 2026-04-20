import Foundation
import CoreGraphics
import AppKit

/// Global push-to-talk watcher using a CGEvent tap.
/// Detects modifier-only hold: press the configured modifier alone → start;
/// release → stop.
final class Hotkey {
    private var spec: HotkeySpec
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressed = false

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    init(spec: HotkeySpec) { self.spec = spec }

    func start() {
        stop()

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) |
                                (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<Hotkey>.fromOpaque(userInfo).takeUnretainedValue()
                me.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            NSLog("personal-stt: failed to create CGEvent tap. Grant Input Monitoring in System Settings.")
            return
        }

        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("personal-stt: hotkey tap active (mask=0x%llx)", spec.modifierMask)
    }

    func stop() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        pressed = false
    }

    func updateSpec(_ spec: HotkeySpec) {
        self.spec = spec
        start()
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard type == .flagsChanged else { return }

        let raw = UInt64(event.flags.rawValue)
        let isDown = (raw & spec.modifierMask) == spec.modifierMask

        if isDown && !pressed {
            pressed = true
            DispatchQueue.main.async { [weak self] in self?.onPress?() }
        } else if !isDown && pressed {
            pressed = false
            DispatchQueue.main.async { [weak self] in self?.onRelease?() }
        }
    }
}
