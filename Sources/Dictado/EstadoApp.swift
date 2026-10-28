import DictadoNucleo
import SwiftUI

/// Las secciones de la barra lateral de la ventana.
enum Seccion: String, CaseIterable, Identifiable {
    case inicio, historial, diccionario, estilo, bola, ajustes

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .inicio: return "Inicio"
        case .historial: return "Historial"
        case .diccionario: return "Diccionario"
        case .estilo: return "Estilo"
        case .bola: return "Bola"
        case .ajustes: return "Ajustes"
        }
    }

    var icono: String {
        switch self {
        case .inicio: return "house"
        case .historial: return "clock"
        case .diccionario: return "book.closed"
        case .estilo: return "textformat"
        case .bola: return "circle.circle"
        case .ajustes: return "gearshape"
        }
    }
}

/// El fondo de la ventana: el azul del diseño, que hace brillar el cristal, o el escritorio desenfocado.
enum FondoDeVentana: String, CaseIterable, Identifiable {
    case azul, escritorio

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .azul: return "Azul"
        case .escritorio: return "Escritorio"
        }
    }
}

/// Lo que la interfaz necesita saber: permisos, preferencias y la sección abierta.
final class EstadoApp: ObservableObject {
    static let compartido = EstadoApp()

    @Published var seccion: Seccion = .inicio
    @Published var fondoVentana: FondoDeVentana {
        didSet { Ajustes.fondoVentana = fondoVentana }
    }
    @Published var microConcedido = Permisos.micro
    @Published var accesibilidadConcedida = Permisos.accesibilidad

    @Published var atajo: Atajo {
        didSet { Ajustes.atajo = atajo }
    }

    @Published var bola: AparienciaBola {
        didSet { Ajustes.bola = bola }
    }

    @Published var estilos: EstilosPorApp {
        didSet { Ajustes.estilos = estilos }
    }

    @Published var escrituraProgresiva: Bool {
        didSet { Ajustes.escrituraProgresiva = escrituraProgresiva }
    }

    @Published var abrirAlIniciar: Bool {
        didSet {
            Ajustes.abrirAlIniciarDeseado = abrirAlIniciar
            AlIniciar.activar(abrirAlIniciar)
        }
    }

    var faltanPermisos: Bool {
        !microConcedido || !accesibilidadConcedida
    }

    var iconoMenu: String {
        faltanPermisos ? "exclamationmark.triangle" : "waveform"
    }

    private init() {
        _fondoVentana = Published(initialValue: Ajustes.fondoVentana)
        _atajo = Published(initialValue: Ajustes.atajo)
        _bola = Published(initialValue: Ajustes.bola)
        _estilos = Published(initialValue: Ajustes.estilos)
        _escrituraProgresiva = Published(initialValue: Ajustes.escrituraProgresiva)
        _abrirAlIniciar = Published(initialValue: AlIniciar.activado)
    }
}
