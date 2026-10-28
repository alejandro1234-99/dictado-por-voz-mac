import Foundation

/// Los estilos de la bola, por familias. Los nombres son los que se ven en los ajustes.
public enum EstiloBola: String, Codable, CaseIterable, Sendable {
    // En 3D
    case perla, cristal, mercurio, grafito, nacar, hielo
    // Metales
    case oro, oroRosa, plata, platino, bronce, cobre, laton, titanio, acero, cromo, aluminio
    // Piedras y gemas
    case marmol, obsidiana, jade, zafiro, esmeralda, rubi
    // Suaves
    case suaveAzul, suavePlata
    // De colores
    case seda, nube, aurora
    // Cápsulas con barras
    case capsulaCristal, capsulaGrafito, capsulaCompacta

    public enum Familia: String, CaseIterable, Sendable {
        case tresD = "En 3D"
        case metales = "Metales"
        case piedras = "Piedras y gemas"
        case suaves = "Suaves"
        case colores = "De colores"
        case capsulas = "Cápsulas"
    }

    public var familia: Familia {
        switch self {
        case .perla, .cristal, .mercurio, .grafito, .nacar, .hielo: return .tresD
        case .oro, .oroRosa, .plata, .platino, .bronce, .cobre, .laton, .titanio, .acero, .cromo, .aluminio: return .metales
        case .marmol, .obsidiana, .jade, .zafiro, .esmeralda, .rubi: return .piedras
        case .suaveAzul, .suavePlata: return .suaves
        case .seda, .nube, .aurora: return .colores
        case .capsulaCristal, .capsulaGrafito, .capsulaCompacta: return .capsulas
        }
    }

    public var nombre: String {
        switch self {
        case .perla: return "Perla"
        case .cristal: return "Cristal"
        case .mercurio: return "Mercurio"
        case .grafito: return "Grafito"
        case .nacar: return "Nácar"
        case .hielo: return "Hielo"
        case .oro: return "Oro"
        case .oroRosa: return "Oro rosa"
        case .plata: return "Plata"
        case .platino: return "Platino"
        case .bronce: return "Bronce"
        case .cobre: return "Cobre"
        case .laton: return "Latón"
        case .titanio: return "Titanio"
        case .acero: return "Acero"
        case .cromo: return "Cromo"
        case .aluminio: return "Aluminio"
        case .marmol: return "Mármol"
        case .obsidiana: return "Obsidiana"
        case .jade: return "Jade"
        case .zafiro: return "Zafiro"
        case .esmeralda: return "Esmeralda"
        case .rubi: return "Rubí"
        case .suaveAzul: return "Azul pálido"
        case .suavePlata: return "Plata suave"
        case .seda: return "Seda"
        case .nube: return "Nube"
        case .aurora: return "Aurora"
        case .capsulaCristal: return "Cristal"
        case .capsulaGrafito: return "Grafito"
        case .capsulaCompacta: return "Compacta"
        }
    }

    public var esCapsula: Bool { familia == .capsulas }

    public static func de(_ familia: Familia) -> [EstiloBola] {
        allCases.filter { $0.familia == familia }
    }

    /// El color de la luz que la rodea, de 0 a 1.
    public var colorHalo: (rojo: Double, verde: Double, azul: Double) {
        switch self {
        case .perla, .suaveAzul, .seda, .capsulaCristal, .capsulaCompacta: return (0.55, 0.72, 1.0)
        case .cristal, .hielo: return (0.62, 0.80, 1.0)
        case .mercurio, .plata, .platino, .acero, .cromo, .aluminio, .suavePlata, .marmol: return (0.85, 0.88, 0.95)
        case .grafito, .obsidiana, .capsulaGrafito: return (0.45, 0.55, 0.72)
        case .nacar: return (0.92, 0.86, 0.95)
        case .oro: return (1.0, 0.80, 0.40)
        case .oroRosa: return (1.0, 0.72, 0.64)
        case .bronce: return (0.88, 0.60, 0.36)
        case .laton: return (1.0, 0.86, 0.48)
        case .cobre: return (0.98, 0.58, 0.44)
        case .titanio: return (0.70, 0.68, 0.72)
        case .jade, .esmeralda: return (0.40, 0.85, 0.62)
        case .zafiro: return (0.30, 0.50, 1.0)
        case .rubi: return (1.0, 0.30, 0.42)
        case .nube: return (0.35, 0.62, 1.0)
        case .aurora: return (0.66, 0.42, 1.0)
        }
    }
}

public enum PosicionBola: String, Codable, CaseIterable, Sendable {
    case abajo, arriba

    public var nombre: String {
        switch self {
        case .abajo: return "Abajo"
        case .arriba: return "Arriba"
        }
    }
}

/// Cómo se ve la bola: lo que se elige en la pestaña «Bola» de los ajustes.
public struct AparienciaBola: Codable, Equatable, Sendable {
    public static let tamanos: ClosedRange<Double> = 40...120
    public static let brillos: ClosedRange<Double> = 0.7...1.3

    public var estilo: EstiloBola
    /// Diámetro en puntos.
    public var tamano: Double
    /// La luz alrededor, de 0, sin luz, a 1, fuerte.
    public var halo: Double
    /// 1 es el brillo normal del material.
    public var brillo: Double
    public var posicion: PosicionBola

    public init(
        estilo: EstiloBola = .perla,
        tamano: Double = 56,
        halo: Double = 0.35,
        brillo: Double = 1,
        posicion: PosicionBola = .abajo
    ) {
        self.estilo = estilo
        self.tamano = min(max(tamano, Self.tamanos.lowerBound), Self.tamanos.upperBound)
        self.halo = min(max(halo, 0), 1)
        self.brillo = min(max(brillo, Self.brillos.lowerBound), Self.brillos.upperBound)
        self.posicion = posicion
    }

    public static let estandar = AparienciaBola()

    private enum Claves: String, CodingKey {
        case estilo, tamano, halo, brillo, posicion
    }

    /// Lo que falte o no se entienda, porque se guardó con otra versión, queda como viene de serie.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Claves.self)
        let serie = AparienciaBola.estandar
        self.init(
            estilo: (try? c.decodeIfPresent(EstiloBola.self, forKey: .estilo)) ?? serie.estilo,
            tamano: (try? c.decodeIfPresent(Double.self, forKey: .tamano)) ?? serie.tamano,
            halo: (try? c.decodeIfPresent(Double.self, forKey: .halo)) ?? serie.halo,
            brillo: (try? c.decodeIfPresent(Double.self, forKey: .brillo)) ?? serie.brillo,
            posicion: (try? c.decodeIfPresent(PosicionBola.self, forKey: .posicion)) ?? serie.posicion
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Claves.self)
        try c.encode(estilo, forKey: .estilo)
        try c.encode(tamano, forKey: .tamano)
        try c.encode(halo, forKey: .halo)
        try c.encode(brillo, forKey: .brillo)
        try c.encode(posicion, forKey: .posicion)
    }
}
