import AppKit
import AudioToolbox

enum Sounds {
    static func start() {
        // System "Tink" — short, unmistakably "on"
        if let s = NSSound(named: NSSound.Name("Tink")) {
            s.play()
            return
        }
        AudioServicesPlaySystemSound(1057)
    }

    static func stop() {
        // "Pop" — short, closing feel
        if let s = NSSound(named: NSSound.Name("Pop")) {
            s.play()
            return
        }
        AudioServicesPlaySystemSound(1114)
    }

    static func error() {
        if let s = NSSound(named: NSSound.Name("Basso")) {
            s.play()
            return
        }
        AudioServicesPlaySystemSound(1073)
    }
}
