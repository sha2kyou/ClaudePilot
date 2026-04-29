import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    static var isSupported: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }

    static func isEnabled() -> Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            return
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
