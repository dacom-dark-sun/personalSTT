import Foundation
import CoreGraphics
import AppKit

/// Fixed two-mode global push-to-talk watcher via a CGEvent tap.
///
/// - **Hold mode** — press Right Option alone to start; release to stop.
/// - **Toggle mode** — press Right Command + Right Option together to start;
///   recording continues after release. Press Right Option again (alone) to stop.
final class Hotkey {
    /// Recording should begin (either mode).
    var onStart: (() -> Void)?
    /// Recording should end (either mode).
    var onStop: (() -> Void)?

    private enum State { case idle, hold, toggle }
    private var state: State = .idle
    private var rightOptionDown = false

    // CGEventFlags bit masks. The low byte is the "device-dependent" bit
    // distinguishing left vs. right modifier on the same physical modifier.
    private let rightOptionMask: UInt64  = 0x00080040
    private let rightCommandMask: UInt64 = 0x00100010

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        stop()

        let mask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue
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
        NSLog("personal-stt: hotkey tap active (right-option hold, right-cmd+right-option toggle)")
    }

    func stop() {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        state = .idle
        rightOptionDown = false
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard type == .flagsChanged else { return }

        let raw = UInt64(event.flags.rawValue)
        let rOpt = (raw & rightOptionMask)  == rightOptionMask
        let rCmd = (raw & rightCommandMask) == rightCommandMask

        let justPressed  = rOpt && !rightOptionDown
        let justReleased = !rOpt && rightOptionDown
        rightOptionDown = rOpt

        if justPressed {
            switch state {
            case .idle:
                if rCmd {
                    state = .toggle
                    NSLog("personal-stt: hotkey → toggle mode start")
                    DispatchQueue.main.async { [weak self] in self?.onStart?() }
                } else {
                    state = .hold
                    NSLog("personal-stt: hotkey → hold mode start")
                    DispatchQueue.main.async { [weak self] in self?.onStart?() }
                }
            case .toggle:
                state = .idle
                NSLog("personal-stt: hotkey → toggle mode stop")
                DispatchQueue.main.async { [weak self] in self?.onStop?() }
            case .hold:
                break
            }
            return
        }

        if justReleased, state == .hold {
            state = .idle
            NSLog("personal-stt: hotkey → hold mode stop")
            DispatchQueue.main.async { [weak self] in self?.onStop?() }
        }
    }
}
