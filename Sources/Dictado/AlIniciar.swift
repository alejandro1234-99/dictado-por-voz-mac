import Foundation
import ServiceManagement

/// Abrir Oxidos OS al iniciar sesión, con el registro de apps de inicio de macOS.
enum AlIniciar {
    static var activado: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func activar(_ encender: Bool) {
        do {
            if encender {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Dictado: no se pudo cambiar «Abrir al iniciar sesión»: \(error.localizedDescription)")
        }
    }
}
