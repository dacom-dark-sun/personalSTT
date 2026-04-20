import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService.mainApp (macOS 13+).
/// The registered .app appears in System Settings → General → Login Items,
/// where the user can also toggle it manually.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled {
                try service.register()
            }
        } else {
            if service.status == .enabled {
                try service.unregister()
            }
        }
    }
}
