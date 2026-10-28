import AppKit
import CoreGraphics
import DictadoNucleo

/// Escucha el atajo de dictado en todo el sistema. Necesita el permiso de Accesibilidad.
final class Tecla {
    var alPulsar: (() -> Void)?
    var alSoltar: (() -> Void)?
    var alCancelar: (() -> Void)?

    /// Mientras se graba un atajo nuevo en la ventana de ajustes, el atajo no dicta.
    static var enPausa = false

    private var tap: CFMachPort?
    private var fuente: CFRunLoopSource?
    private var detector = DetectorAtajo(atajo: Ajustes.atajo)

    var activa: Bool { tap != nil }

    func arrancar() -> Bool {
        guard tap == nil else { return true }
        let tipos: [CGEventType] = [.flagsChanged, .keyDown, .keyUp]
        let mascara = tipos.reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
        let yo = Unmanaged.passUnretained(self).toOpaque()
        guard let nuevo = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mascara,
            callback: { _, tipo, evento, puntero in
                guard let puntero else { return Unmanaged.passUnretained(evento) }
                let tecla = Unmanaged<Tecla>.fromOpaque(puntero).takeUnretainedValue()
                // Devolver nada se queda la tecla: no llega a la app que está delante.
                return tecla.recibir(tipo: tipo, evento: evento) ? nil : Unmanaged.passUnretained(evento)
            },
            userInfo: yo
        ) else {
            return false
        }
        tap = nuevo
        fuente = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, nuevo, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), fuente, .commonModes)
        CGEvent.tapEnable(tap: nuevo, enable: true)
        return true
    }

    /// Devuelve si la tecla se queda aquí.
    private func recibir(tipo: CGEventType, evento: CGEvent) -> Bool {
        // macOS apaga el tap si tarda o si lo pide el usuario: se vuelve a encender.
        if tipo == .tapDisabledByTimeout || tipo == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        // Las pulsaciones con las que la propia app escribe el texto no son del usuario.
        if evento.getIntegerValueField(.eventSourceUserData) == Insertador.marca {
            return false
        }
        if detector.atajo != Ajustes.atajo {
            detector = DetectorAtajo(atajo: Ajustes.atajo)
        }
        // La pausa solo vale con la ventana delante: si se cierra mientras graba, el atajo vuelve a dictar.
        let grabandoAtajo = Tecla.enPausa && NSApp.isActive
        guard !grabandoAtajo, let suceso = Self.traducir(tipo: tipo, evento: evento) else { return false }

        let respuesta = detector.recibir(suceso)
        switch respuesta.accion {
        case .empezar: alPulsar?()
        case .terminar: alSoltar?()
        case .cancelar: alCancelar?()
        case nil: break
        }
        return respuesta.tragar
    }

    private static func traducir(tipo: CGEventType, evento: CGEvent) -> EventoTecla? {
        let modificadores = Self.modificadores(evento.flags)
        let codigo = UInt16(truncatingIfNeeded: evento.getIntegerValueField(.keyboardEventKeycode))
        switch tipo {
        case .flagsChanged:
            return .modificadores(modificadores)
        case .keyDown:
            let repetida = evento.getIntegerValueField(.keyboardEventAutorepeat) != 0
            return .abajo(tecla: codigo, modificadores: modificadores, repetida: repetida)
        case .keyUp:
            return .arriba(tecla: codigo, modificadores: modificadores)
        default:
            return nil
        }
    }

    private static func modificadores(_ flags: CGEventFlags) -> Modificadores {
        var modificadores: Modificadores = []
        if flags.contains(.maskControl) { modificadores.insert(.control) }
        if flags.contains(.maskAlternate) { modificadores.insert(.opcion) }
        if flags.contains(.maskShift) { modificadores.insert(.mayusculas) }
        if flags.contains(.maskCommand) { modificadores.insert(.comando) }
        if flags.contains(.maskSecondaryFn) { modificadores.insert(.fn) }
        return modificadores
    }
}
