import AppKit
import DictadoNucleo

/// Un dictado del historial, tal como se enseña en la ventana.
struct DictadoGuardado: Identifiable, Equatable {
    let id: String
    let fecha: Date
    let app: String?
    let appBundle: String?
    /// Lo que se escribió, ya con el estilo; si es un dictado antiguo, lo que dio el motor.
    let texto: String
    /// Lo que dio el motor de voz, sin tocar.
    let crudo: String?
    let palabras: Int
    let segundos: Double
}

extension Notification.Name {
    /// Se acaba de guardar un dictado: la ventana vuelve a leer el historial.
    static let dictadoGuardado = Notification.Name("Dictado.dictadoGuardado")
}

/// Lo que enseña la ventana, leído del historial del Mac: métricas, últimos dictados y diccionario.
final class DatosApp: ObservableObject {
    static let compartido = DatosApp()

    @Published private(set) var metricas = Metricas()
    @Published private(set) var ultimos: [DictadoGuardado] = []
    @Published private(set) var diccionario: [EntradaDiccionario] = []

    private let almacen = Almacen.compartido
    private var observador: NSObjectProtocol?

    /// La semana empieza en lunes, como en España.
    static var calendario: Calendar {
        var calendario = Calendar.current
        calendario.firstWeekday = 2
        return calendario
    }

    private init() {
        recargar()
        observador = NotificationCenter.default.addObserver(
            forName: .dictadoGuardado, object: nil, queue: .main
        ) { [weak self] _ in
            self?.recargar()
        }
    }

    func recargar() {
        guard let almacen else { return }
        metricas = Metricas.calcular(almacen.registrosParaMetricas(), calendario: Self.calendario)
        ultimos = almacen.dictados(limite: 5)
        diccionario = almacen.diccionario()
    }

    func historial(buscando texto: String) -> [DictadoGuardado] {
        almacen?.dictados(buscando: texto) ?? []
    }

    func borrar(_ dictado: DictadoGuardado) {
        almacen?.borrarDictado(id: dictado.id)
        recargar()
    }

    /// Añade una palabra propia o, si se dice cómo se oye, una corrección.
    func anadir(palabra: String, seOye: String?) {
        let limpia = palabra.trimmingCharacters(in: .whitespacesAndNewlines)
        let oido = seOye?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return }
        almacen?.guardar(EntradaDiccionario(palabra: limpia, seOye: (oido?.isEmpty ?? true) ? nil : oido))
        recargar()
    }

    func borrar(_ entrada: EntradaDiccionario) {
        almacen?.borrarDelDiccionario(id: entrada.id)
        recargar()
    }

    static func copiar(_ texto: String) {
        let tablero = NSPasteboard.general
        tablero.clearContents()
        tablero.setString(texto, forType: .string)
    }
}
