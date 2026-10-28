import AppKit
import ApplicationServices

/// Qué hay justo antes del cursor en la app de delante, leído con el permiso de Accesibilidad.
enum ContextoCursor {
    enum Lectura {
        case caracter(Character)
        /// El cursor está al principio del campo o el campo está vacío.
        case alPrincipio
        /// La app no deja leerlo.
        case desconocido
    }

    /// Chrome, Slack, VS Code y demás apps hechas con Electron solo enseñan su texto a Accesibilidad si se les pide.
    static func prepararApp(_ app: NSRunningApplication?) {
        guard let pid = app?.processIdentifier else { return }
        let elemento = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(elemento, 0.2)
        AXUIElementSetAttributeValue(elemento, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    static func leer() -> Lectura {
        let sistema = AXUIElementCreateSystemWide()
        // Si la app no responde, mejor no saber que dejar el dictado esperando.
        AXUIElementSetMessagingTimeout(sistema, 0.2)
        var foco: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sistema, kAXFocusedUIElementAttribute as CFString, &foco) == .success,
              let foco, CFGetTypeID(foco) == AXUIElementGetTypeID() else {
            return .desconocido
        }
        let elemento = foco as! AXUIElement
        AXUIElementSetMessagingTimeout(elemento, 0.2)

        var valorRango: CFTypeRef?
        guard AXUIElementCopyAttributeValue(elemento, kAXSelectedTextRangeAttribute as CFString, &valorRango) == .success,
              let valorRango, CFGetTypeID(valorRango) == AXValueGetTypeID() else {
            return .desconocido
        }
        var rango = CFRange()
        guard AXValueGetValue(valorRango as! AXValue, .cfRange, &rango) else { return .desconocido }
        if rango.location <= 0 { return .alPrincipio }

        // Primero solo el carácter de antes; si la app no lo da así, del texto entero del campo.
        var anterior = CFRange(location: rango.location - 1, length: 1)
        if let parametro = AXValueCreate(.cfRange, &anterior) {
            var trozo: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(
                elemento, kAXStringForRangeParameterizedAttribute as CFString, parametro, &trozo
            ) == .success, let texto = trozo as? String, let letra = texto.last {
                return .caracter(letra)
            }
        }
        var valor: CFTypeRef?
        guard AXUIElementCopyAttributeValue(elemento, kAXValueAttribute as CFString, &valor) == .success,
              let texto = valor as? String else {
            return .desconocido
        }
        let nsTexto = texto as NSString
        guard rango.location <= nsTexto.length else { return .desconocido }
        let letra = nsTexto.substring(with: NSRange(location: rango.location - 1, length: 1))
        return letra.last.map { .caracter($0) } ?? .desconocido
    }
}
