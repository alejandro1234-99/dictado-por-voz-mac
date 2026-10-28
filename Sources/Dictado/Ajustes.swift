import DictadoNucleo
import Foundation

/// Preferencias guardadas en UserDefaults.
enum Ajustes {
    private static let defaults = UserDefaults.standard

    /// El atajo para dictar. Se lee una vez y se queda en memoria: la tecla lo consulta en cada pulsación.
    static var atajo: Atajo = leerAtajo() {
        didSet {
            if let datos = try? JSONEncoder().encode(atajo) {
                defaults.set(datos, forKey: "atajo")
            }
        }
    }

    private static func leerAtajo() -> Atajo {
        if let datos = defaults.data(forKey: "atajo"),
           let atajo = try? JSONDecoder().decode(Atajo.self, from: datos) {
            return atajo
        }
        // La primera versión solo dejaba elegir entre Fn y Control + Opción.
        if defaults.string(forKey: "tecla") == "controlOpcion" {
            return Atajo(modificadores: [.control, .opcion])
        }
        return .fn
    }

    /// Cómo se ve la bola. Se lee al empezar cada dictado.
    static var bola: AparienciaBola = leerBola() {
        didSet {
            if let datos = try? JSONEncoder().encode(bola) {
                defaults.set(datos, forKey: "bola")
            }
        }
    }

    private static func leerBola() -> AparienciaBola {
        guard let datos = defaults.data(forKey: "bola"),
              let bola = try? JSONDecoder().decode(AparienciaBola.self, from: datos) else {
            return .estandar
        }
        return bola
    }

    /// El estilo de escritura de cada tipo de app.
    static var estilos: EstilosPorApp = leerEstilos() {
        didSet {
            if let datos = try? JSONEncoder().encode(estilos) {
                defaults.set(datos, forKey: "estilos")
            }
        }
    }

    private static func leerEstilos() -> EstilosPorApp {
        guard let datos = defaults.data(forKey: "estilos"),
              let estilos = try? JSONDecoder().decode(EstilosPorApp.self, from: datos) else {
            return .estandar
        }
        return estilos
    }

    /// Si el texto cae palabra a palabra o se pega de golpe. De serie, palabra a palabra.
    static var escrituraProgresiva: Bool {
        get { defaults.object(forKey: "escrituraProgresiva") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "escrituraProgresiva") }
    }

    /// El fondo de la ventana. De serie, el azul del diseño.
    static var fondoVentana: FondoDeVentana {
        get { FondoDeVentana(rawValue: defaults.string(forKey: "fondoVentana") ?? "") ?? .azul }
        set { defaults.set(newValue.rawValue, forKey: "fondoVentana") }
    }

    /// Lo que se eligió en «Abrir al iniciar sesión», para volver a apuntarlo si macOS lo olvida, como al cambiar
    /// el nombre de la app. De serie, sí.
    static var abrirAlIniciarDeseado: Bool {
        get { defaults.object(forKey: "abrirAlIniciarDeseado") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "abrirAlIniciarDeseado") }
    }

    static var bienvenidaVista: Bool {
        get { defaults.bool(forKey: "bienvenidaVista") }
        set { defaults.set(newValue, forKey: "bienvenidaVista") }
    }
}
