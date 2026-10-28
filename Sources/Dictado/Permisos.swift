import AppKit
import ApplicationServices
import AVFoundation

enum Permisos {
    enum Panel {
        case micro, accesibilidad, teclado

        var url: URL {
            switch self {
            case .micro:
                return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
            case .accesibilidad:
                return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            case .teclado:
                return URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!
            }
        }
    }

    static var micro: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static var accesibilidad: Bool {
        AXIsProcessTrusted()
    }

    /// La primera vez sale el aviso de macOS; si ya se denegó, se abre el panel de Ajustes.
    static func pedirMicro(_ hecho: @escaping (Bool) -> Void) {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { concedido in
                DispatchQueue.main.async { hecho(concedido) }
            }
        } else {
            abrir(.micro)
        }
    }

    /// Pone Dictado en la lista de Accesibilidad y abre el panel para activarlo.
    static func pedirAccesibilidad() {
        let opciones = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opciones) {
            abrir(.accesibilidad)
        }
    }

    static func abrir(_ panel: Panel) {
        NSWorkspace.shared.open(panel.url)
    }
}
