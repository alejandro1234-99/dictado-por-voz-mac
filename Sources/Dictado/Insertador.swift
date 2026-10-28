import AppKit
import CoreGraphics
import DictadoNucleo

/// Escribe el texto donde está el cursor: palabra a palabra, como si cayera, o pegado de una vez con Cmd+V.
final class Insertador {
    /// Marca de las pulsaciones que manda la app, para que la tecla de dictado no las tome por suyas.
    static let marca: Int64 = 0x4449_4354
    /// Lo que tarda en caer el texto entero, como mucho, con una pausa de 12 ms entre palabras en los textos cortos.
    private static let duracionMaxima = 0.16
    private static let pausaMaxima = 0.012

    private let cola = DispatchQueue(label: "Dictado.insertador", qos: .userInteractive)

    func escribir(_ texto: String, palabraAPalabra: Bool) {
        // Un salto de línea escrito sería un Intro, y en una app de mensajes enviaría el mensaje: esos textos se pegan.
        guard palabraAPalabra, !texto.contains("\n"), texto.count <= 1000 else {
            pegar(texto)
            return
        }
        let trozos = Texto.trozos(texto)
        let pausa = min(Self.pausaMaxima, Self.duracionMaxima / Double(max(trozos.count, 1)))
        cola.async {
            let fuente = CGEventSource(stateID: .hidSystemState)
            for trozo in trozos {
                Self.teclear(trozo, fuente: fuente)
                Thread.sleep(forTimeInterval: pausa)
            }
        }
    }

    /// Manda el trozo como una pulsación que trae el texto dentro: no pasa por el portapapeles ni depende del teclado.
    /// Sin modificadores, aunque el usuario aún tenga alguno pulsado. El texto va solo al bajar la tecla: si también
    /// va al soltarla, VS Code y otras apps lo escriben dos veces.
    private static func teclear(_ trozo: String, fuente: CGEventSource?) {
        let unidades = Array(trozo.utf16)
        for abajo in [true, false] {
            guard let evento = CGEvent(keyboardEventSource: fuente, virtualKey: 0, keyDown: abajo) else { continue }
            evento.flags = []
            evento.setIntegerValueField(.eventSourceUserData, value: marca)
            if abajo {
                unidades.withUnsafeBufferPointer { bufer in
                    evento.keyboardSetUnicodeString(stringLength: bufer.count, unicodeString: bufer.baseAddress)
                }
            }
            evento.post(tap: .cghidEventTap)
        }
    }

    /// Pega el texto con Cmd+V y deja el portapapeles como estaba.
    func pegar(_ texto: String) {
        let tablero = NSPasteboard.general
        let copia = guardar(tablero)
        tablero.clearContents()
        tablero.setString(texto, forType: .string)
        pulsarComandoV()
        // La app de destino lee el portapapeles al recibir Cmd+V: se restaura un poco después.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.restaurar(copia, en: tablero)
        }
    }

    private func pulsarComandoV() {
        let fuente = CGEventSource(stateID: .combinedSessionState)
        let teclaV: CGKeyCode = 9  // kVK_ANSI_V
        for abajo in [true, false] {
            guard let evento = CGEvent(keyboardEventSource: fuente, virtualKey: teclaV, keyDown: abajo) else { continue }
            evento.flags = .maskCommand
            evento.setIntegerValueField(.eventSourceUserData, value: Self.marca)
            evento.post(tap: .cghidEventTap)
        }
    }

    /// Todo lo que había, con todos sus tipos: texto, imágenes, archivos.
    private func guardar(_ tablero: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (tablero.pasteboardItems ?? []).map { elemento in
            var datos: [NSPasteboard.PasteboardType: Data] = [:]
            for tipo in elemento.types {
                if let dato = elemento.data(forType: tipo) {
                    datos[tipo] = dato
                }
            }
            return datos
        }
    }

    private func restaurar(_ copia: [[NSPasteboard.PasteboardType: Data]], en tablero: NSPasteboard) {
        tablero.clearContents()
        let elementos = copia.map { datos -> NSPasteboardItem in
            let elemento = NSPasteboardItem()
            for (tipo, dato) in datos {
                elemento.setData(dato, forType: tipo)
            }
            return elemento
        }
        if !elementos.isEmpty {
            tablero.writeObjects(elementos)
        }
    }
}
