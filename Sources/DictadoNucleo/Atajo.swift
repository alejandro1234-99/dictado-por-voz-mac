import Foundation

/// Las teclas modificadoras que puede llevar un atajo.
public struct Modificadores: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = Modificadores(rawValue: 1 << 0)
    public static let opcion = Modificadores(rawValue: 1 << 1)
    public static let mayusculas = Modificadores(rawValue: 1 << 2)
    public static let comando = Modificadores(rawValue: 1 << 3)
    public static let fn = Modificadores(rawValue: 1 << 4)

    public var cuantos: Int { rawValue.nonzeroBitCount }

    /// Con los símbolos de macOS y en su orden: 🌐⌃⌥⇧⌘.
    public var simbolos: String {
        let orden: [(Modificadores, String)] = [(.fn, "🌐"), (.control, "⌃"), (.opcion, "⌥"), (.mayusculas, "⇧"), (.comando, "⌘")]
        return orden.filter { contains($0.0) }.map { $0.1 }.joined()
    }
}

/// Códigos de tecla de macOS que hacen falta para nombrar y validar atajos.
public enum Teclas {
    public static let escape: UInt16 = 53

    private static let funcion: [UInt16: Int] = [
        122: 1, 120: 2, 99: 3, 118: 4, 96: 5, 97: 6, 98: 7, 100: 8, 101: 9, 109: 10,
        103: 11, 111: 12, 105: 13, 107: 14, 113: 15, 106: 16, 64: 17, 79: 18, 80: 19, 90: 20,
    ]
    private static let especiales: [UInt16: String] = [
        53: "Esc", 49: "Espacio", 36: "↩", 76: "⌅", 48: "⇥", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
    ]

    public static func esFuncion(_ tecla: UInt16) -> Bool {
        funcion[tecla] != nil
    }

    /// El nombre de las teclas que no escriben una letra. Las demás se nombran con lo que escribe el teclado.
    public static func nombre(de tecla: UInt16) -> String? {
        if let numero = funcion[tecla] { return "F\(numero)" }
        return especiales[tecla]
    }
}

/// El atajo que se mantiene pulsado para dictar: solo modificadores, como Fn o ⌃⌥, o modificadores y una tecla.
public struct Atajo: Codable, Equatable, Sendable {
    public var modificadores: Modificadores
    /// Código de tecla de macOS, o nada si el atajo es solo de modificadores.
    public var tecla: UInt16?
    /// Cómo se ve la tecla, tal como la escribió el teclado al grabarla: «K», «Ñ», «Espacio».
    public var nombreTecla: String?

    public init(modificadores: Modificadores, tecla: UInt16? = nil, nombreTecla: String? = nil) {
        self.modificadores = modificadores
        self.tecla = tecla
        self.nombreTecla = nombreTecla
    }

    public static let fn = Atajo(modificadores: .fn)

    public var nombre: String {
        guard tecla != nil else {
            return modificadores == .fn ? "Fn 🌐" : modificadores.simbolos
        }
        let teclaVisible = nombreTecla ?? "?"
        let separador = modificadores.isEmpty || teclaVisible.count == 1 ? "" : " "
        return modificadores.simbolos + separador + teclaVisible
    }

    public enum Problema: Equatable, Sendable {
        case unaSolaModificadora
        case sinModificadores

        public var explicacion: String {
            switch self {
            case .unaSolaModificadora:
                return "Una sola tecla, salvo Fn, saltaría al escribir. Usa dos, como ⌃⌥."
            case .sinModificadores:
                return "Una tecla sola saltaría al escribir. Añádele ⌘, ⌃ u ⌥."
            }
        }
    }

    /// Por qué no vale como atajo, o nada si vale.
    public var problema: Problema? {
        if let tecla {
            return modificadores.isEmpty && !Teclas.esFuncion(tecla) ? .sinModificadores : nil
        }
        if modificadores == .fn { return nil }
        return modificadores.cuantos < 2 ? .unaSolaModificadora : nil
    }
}

/// Lo que pasa en el teclado, ya sin nada propio de macOS.
public enum EventoTecla: Equatable, Sendable {
    case modificadores(Modificadores)
    case abajo(tecla: UInt16, modificadores: Modificadores, repetida: Bool)
    case arriba(tecla: UInt16, modificadores: Modificadores)
}

/// Decide, tecla a tecla, cuándo empieza y acaba un dictado con el atajo elegido.
public struct DetectorAtajo {
    public enum Accion: Equatable, Sendable {
        case empezar
        case terminar
        /// Se pulsó otra tecla con el atajo de modificadores: era un atajo del Mac, no un dictado.
        case cancelar
    }

    public struct Respuesta: Equatable, Sendable {
        public var accion: Accion?
        /// Si la tecla se queda aquí y no llega a la app que está delante.
        public var tragar: Bool

        public init(accion: Accion?, tragar: Bool) {
            self.accion = accion
            self.tragar = tragar
        }

        static let nada = Respuesta(accion: nil, tragar: false)
    }

    public let atajo: Atajo
    public private(set) var pulsado = false
    /// Tras cancelar, el atajo no vuelve a valer hasta soltar sus modificadores.
    private var bloqueado = false
    /// La tecla del atajo se soltará después: tampoco tiene que llegar a la app.
    private var tragarArriba = false

    public init(atajo: Atajo) {
        self.atajo = atajo
    }

    public mutating func recibir(_ evento: EventoTecla) -> Respuesta {
        switch evento {
        case .modificadores(let modificadores):
            let siguenPulsados = modificadores.isSuperset(of: atajo.modificadores)
            if !siguenPulsados { bloqueado = false }
            if pulsado && !siguenPulsados {
                pulsado = false
                return Respuesta(accion: .terminar, tragar: false)
            }
            if atajo.tecla == nil && !pulsado && !bloqueado && modificadores == atajo.modificadores {
                pulsado = true
                return Respuesta(accion: .empezar, tragar: false)
            }
            return .nada

        case .abajo(let tecla, let modificadores, let repetida):
            guard let teclaAtajo = atajo.tecla else {
                if pulsado {
                    pulsado = false
                    bloqueado = true
                    return Respuesta(accion: .cancelar, tragar: false)
                }
                return .nada
            }
            guard tecla == teclaAtajo else { return .nada }
            if pulsado { return Respuesta(accion: nil, tragar: true) }
            // Las flechas y las teclas F llevan Fn por su cuenta: en un atajo con tecla, Fn no cuenta.
            guard !repetida, modificadores.subtracting(.fn) == atajo.modificadores else { return .nada }
            pulsado = true
            tragarArriba = true
            return Respuesta(accion: .empezar, tragar: true)

        case .arriba(let tecla, _):
            guard let teclaAtajo = atajo.tecla, tecla == teclaAtajo, tragarArriba else { return .nada }
            tragarArriba = false
            if pulsado {
                pulsado = false
                return Respuesta(accion: .terminar, tragar: true)
            }
            return Respuesta(accion: nil, tragar: true)
        }
    }
}

/// Graba un atajo nuevo con lo que se pulsa en la ventana de ajustes.
public struct GrabacionAtajo {
    public enum Resultado: Equatable, Sendable {
        case listo(Atajo)
        case cancelado
        case rechazado(Atajo.Problema)
    }

    /// Todos los modificadores que se han llegado a pulsar a la vez: el atajo se cierra al soltarlos.
    private var maximo: Modificadores = []

    public init() {}

    /// `nombreTecla` es lo que escribe la tecla en el teclado del Mac; solo hace falta al pulsar una tecla.
    public mutating func recibir(_ evento: EventoTecla, nombreTecla: String? = nil) -> Resultado? {
        switch evento {
        case .modificadores(let modificadores):
            if !modificadores.isEmpty {
                maximo.formUnion(modificadores)
                return nil
            }
            guard !maximo.isEmpty else { return nil }
            let atajo = Atajo(modificadores: maximo)
            maximo = []
            return Self.validar(atajo)

        case .abajo(let tecla, let modificadores, let repetida):
            guard !repetida else { return nil }
            let sinFn = modificadores.subtracting(.fn)
            if tecla == Teclas.escape && sinFn.isEmpty { return .cancelado }
            maximo = []
            return Self.validar(Atajo(
                modificadores: sinFn,
                tecla: tecla,
                nombreTecla: Teclas.nombre(de: tecla) ?? nombreTecla?.uppercased()
            ))

        case .arriba:
            return nil
        }
    }

    private static func validar(_ atajo: Atajo) -> Resultado {
        atajo.problema.map { .rechazado($0) } ?? .listo(atajo)
    }
}
