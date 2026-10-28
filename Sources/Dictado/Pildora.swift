import AppKit
import DictadoNucleo
import SwiftUI

/// El volumen de la voz, de 0 a 1, y si el micro sigue abierto. Lo escribe el hilo de audio y lo lee la bola en cada
/// fotograma.
final class NivelVoz {
    private let cerrojo = NSLock()
    private var valor: Double = 0
    private var abierto = true

    func poner(_ nuevo: Double) {
        cerrojo.lock()
        valor = nuevo
        cerrojo.unlock()
    }

    func leer() -> Double {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return valor
    }

    /// Con el micro cerrado, mientras se escribe el texto, las cápsulas hacen una onda en vez de seguir la voz.
    var escuchando: Bool {
        get {
            cerrojo.lock()
            defer { cerrojo.unlock() }
            return abierto
        }
        set {
            cerrojo.lock()
            abierto = newValue
            cerrojo.unlock()
        }
    }
}

/// La bola mientras se dicta, con el estilo, el tamaño y la posición de los ajustes. No coge el foco ni recibe clics.
/// Se mueve con la voz mientras la tecla está pulsada y se queda en calma mientras se escribe el texto.
final class Pildora {
    let nivel = NivelVoz()
    /// El panel del dictado en curso. Cada dictado tiene el suyo: si se dicta otra vez mientras el anterior aún se
    /// desvanece, el fundido de salida no puede dejar invisible la bola nueva (pasaba a veces).
    private var panel: NSPanel?

    func mostrar() {
        // Si quedaba uno a medias, se quita ya.
        panel?.orderOut(nil)
        nivel.poner(0)
        nivel.escuchando = true
        let apariencia = Ajustes.bola
        let lado = VistaIndicador.lado(para: apariencia)
        let panel = crear()
        self.panel = panel
        panel.setContentSize(NSSize(width: lado, height: lado))
        panel.contentView = NSHostingView(rootView: VistaIndicador(apariencia: apariencia, nivel: nivel))
        if let pantalla = Self.pantallaDelRaton() {
            let marco = pantalla.visibleFrame
            // La bola queda a 24 puntos del borde; el resto del panel es transparente, para la luz de alrededor.
            let mitad = VistaIndicador.altoVisible(para: apariencia) / 2
            let centro = apariencia.posicion == .abajo ? marco.minY + 24 + mitad : marco.maxY - 24 - mitad
            panel.setFrameOrigin(NSPoint(x: marco.midX - lado / 2, y: centro - lado / 2))
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    /// Al soltar la tecla el micro ya está cerrado: la bola gira despacio hasta que se pega el texto.
    func calmar() {
        nivel.poner(0)
        nivel.escuchando = false
    }

    func ocultar() {
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup({ contexto in
            contexto.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    /// Con varias pantallas, la que se está mirando: la del ratón. Si no, la principal.
    private static func pantallaDelRaton() -> NSScreen? {
        let raton = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(raton, $0.frame, false) } ?? NSScreen.main
    }

    private func crear() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        // Por encima de todas las ventanas, y visible aunque Dictado no sea la app de delante: desde que la app está
        // en el Dock, macOS escondía la bola al dictar en otra app.
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // La sombra y la luz las dibuja la bola; la sombra de la ventana se vería cuadrada.
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }
}
