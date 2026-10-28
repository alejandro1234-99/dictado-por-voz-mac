import Foundation

/// Una palabra propia, como un nombre o un término técnico, o una corrección: «si oyes X, escribe Y».
public struct EntradaDiccionario: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    /// Cómo se escribe: «GitHub».
    public var palabra: String
    /// Cómo lo entiende mal el motor de voz, si es una corrección: «guit hab». Sin él, es una palabra propia.
    public var seOye: String?

    public init(id: String = UUID().uuidString, palabra: String, seOye: String? = nil) {
        self.id = id
        self.palabra = palabra
        self.seOye = seOye
    }

    public var esCorreccion: Bool { seOye != nil }
}

public enum Diccionario {
    /// Lo que se le pasa al motor de voz para que reconozca mejor: cómo se escriben las palabras propias.
    public static func palabrasParaElMotor(_ entradas: [EntradaDiccionario]) -> [String] {
        var vistas = Set<String>()
        return entradas.map(\.palabra).filter { vistas.insert($0.lowercased()).inserted }
    }

    /// Cambia lo que el motor entendió mal por cómo se escribe, y pone las palabras propias con sus mayúsculas.
    /// Solo palabras enteras, sin importar mayúsculas ni espacios de más; las frases largas van primero.
    public static func aplicar(_ entradas: [EntradaDiccionario], a texto: String) -> String {
        let cambios = entradas
            .map { (buscar: $0.seOye ?? $0.palabra, poner: $0.palabra) }
            .filter { !$0.buscar.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.buscar.count > $1.buscar.count }
        var resultado = texto
        for cambio in cambios {
            guard let expresion = expresion(para: cambio.buscar) else { continue }
            let rango = NSRange(resultado.startIndex..., in: resultado)
            let plantilla = NSRegularExpression.escapedTemplate(for: cambio.poner)
            resultado = expresion.stringByReplacingMatches(in: resultado, range: rango, withTemplate: plantilla)
        }
        return resultado
    }

    private static func expresion(para frase: String) -> NSRegularExpression? {
        let palabras = frase.split(whereSeparator: \.isWhitespace).map { NSRegularExpression.escapedPattern(for: String($0)) }
        let patron = #"(?<![\p{L}\p{N}])"# + palabras.joined(separator: #"\s+"#) + #"(?![\p{L}\p{N}])"#
        return try? NSRegularExpression(pattern: patron, options: [.caseInsensitive])
    }
}
