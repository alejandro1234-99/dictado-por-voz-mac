import Foundation

/// Cómo se escribe el texto dictado, como los estilos de Wispr Flow pero en español.
public enum EstiloEscritura: String, Codable, CaseIterable, Sendable {
    /// Mayúsculas, signos de apertura y punto final.
    case formal
    /// Mayúsculas, sin signos de apertura ni punto final.
    case casual
    /// Como casual y, además, sin mayúscula al empezar.
    case muyCasual
    /// Como formal, pero acaba con exclamación.
    case entusiasta

    public var nombre: String {
        switch self {
        case .formal: return "Formal"
        case .casual: return "Casual"
        case .muyCasual: return "Muy casual"
        case .entusiasta: return "Entusiasta"
        }
    }

    public var ejemplo: String {
        Texto.preparar("hola, quedamos mañana? te paso el documento", estilo: self)
    }
}

/// El tipo de app en la que se dicta, por su identificador de macOS.
public enum TipoApp: String, Codable, CaseIterable, Sendable {
    case personal, trabajo, email, otras

    public var nombre: String {
        switch self {
        case .personal: return "Mensajes personales"
        case .trabajo: return "Mensajes de trabajo"
        case .email: return "Correo"
        case .otras: return "Otras apps"
        }
    }

    private static let personales: Set<String> = [
        "net.whatsapp.whatsapp", "desktop.whatsapp", "com.apple.mobilesms", "com.apple.ichat",
        "ru.keepcoder.telegram", "org.telegram.desktop", "com.hnc.discord", "com.facebook.archon",
        "com.facebook.archon.developerid", "org.whispersystems.signal-desktop",
    ]
    private static let deTrabajo: Set<String> = [
        "com.tinyspeck.slackmacgap", "com.microsoft.teams", "com.microsoft.teams2", "com.linear", "notion.id",
        "us.zoom.xos", "com.google.chat",
    ]
    private static let deCorreo: Set<String> = [
        "com.apple.mail", "com.microsoft.outlook", "com.readdle.smartemail-mac", "com.superhuman.electron",
        "com.mimestream.mimestream", "it.bloop.airmail2",
    ]

    public static func de(bundle: String?) -> TipoApp {
        guard let bundle = bundle?.lowercased() else { return .otras }
        if personales.contains(bundle) { return .personal }
        if deTrabajo.contains(bundle) { return .trabajo }
        if deCorreo.contains(bundle) { return .email }
        return .otras
    }
}

/// El estilo elegido para cada tipo de app. De serie, Casual en los mensajes personales y Formal en lo demás.
public struct EstilosPorApp: Codable, Equatable, Sendable {
    public var personal: EstiloEscritura
    public var trabajo: EstiloEscritura
    public var email: EstiloEscritura
    public var otras: EstiloEscritura

    public init(
        personal: EstiloEscritura = .casual,
        trabajo: EstiloEscritura = .formal,
        email: EstiloEscritura = .formal,
        otras: EstiloEscritura = .formal
    ) {
        self.personal = personal
        self.trabajo = trabajo
        self.email = email
        self.otras = otras
    }

    public static let estandar = EstilosPorApp()

    public subscript(tipo: TipoApp) -> EstiloEscritura {
        get {
            switch tipo {
            case .personal: return personal
            case .trabajo: return trabajo
            case .email: return email
            case .otras: return otras
            }
        }
        set {
            switch tipo {
            case .personal: personal = newValue
            case .trabajo: trabajo = newValue
            case .email: email = newValue
            case .otras: otras = newValue
            }
        }
    }

    private enum Claves: String, CodingKey {
        case personal, trabajo, email, otras
    }

    /// Lo que falte o no se entienda queda como viene de serie.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Claves.self)
        let serie = EstilosPorApp.estandar
        self.init(
            personal: (try? c.decodeIfPresent(EstiloEscritura.self, forKey: .personal)) ?? serie.personal,
            trabajo: (try? c.decodeIfPresent(EstiloEscritura.self, forKey: .trabajo)) ?? serie.trabajo,
            email: (try? c.decodeIfPresent(EstiloEscritura.self, forKey: .email)) ?? serie.email,
            otras: (try? c.decodeIfPresent(EstiloEscritura.self, forKey: .otras)) ?? serie.otras
        )
    }
}

/// Deja el texto del motor de voz listo para pegar: órdenes habladas, espacios, signos y estilo.
public enum Texto {
    public static func preparar(_ crudo: String, estilo: EstiloEscritura) -> String {
        let limpio = espacios(ordenes(crudo))
        return aplicar(estilo, a: limpio)
    }

    /// Un dictado que sigue a texto ya escrito empieza con un espacio, salvo que justo antes haya un espacio, un salto o
    /// un signo de apertura. Si no se sabe qué hay antes del cursor, no se añade nada.
    public static func unir(_ texto: String, tras anterior: Character?) -> String {
        guard let anterior, !texto.isEmpty, let primero = texto.first else { return texto }
        if anterior.isWhitespace || anterior.isNewline || "¿¡([{«\"'".contains(anterior) { return texto }
        if primero.isWhitespace || primero.isNewline || ",.;:?!…)".contains(primero) { return texto }
        return " " + texto
    }

    /// Trozos para escribir el texto palabra a palabra: cada palabra con el espacio que la sigue. macOS no admite más de
    /// 20 caracteres UTF-16 por pulsación, así que las palabras más largas van en varios trozos, sin partir letras.
    public static func trozos(_ texto: String, maximo: Int = 20) -> [String] {
        var resultado: [String] = []
        var actual = ""
        var unidades = 0
        var enEspacio = false
        for letra in texto {
            let cuenta = letra.utf16.count
            let esEspacio = letra.isWhitespace
            // Una palabra nueva empieza tras su espacio; un trozo lleno, en cualquier caso.
            if (!esEspacio && enEspacio) || unidades + cuenta > maximo, !actual.isEmpty {
                resultado.append(actual)
                actual = ""
                unidades = 0
            }
            actual.append(letra)
            unidades += cuenta
            enEspacio = esEspacio
        }
        if !actual.isEmpty {
            resultado.append(actual)
        }
        return resultado
    }

    // MARK: - Órdenes habladas

    private static let ordenesHabladas: [(NSRegularExpression, String)] = [
        (regla(#"[,;:]?\s*\bnuevo\s+p[aá]rrafo\b[,.;:]?\s*"#), "\n\n"),
        (regla(#"[,;:]?\s*\bnueva\s+l[ií]nea\b[,.;:]?\s*"#), "\n"),
    ]

    /// «nueva línea» y «nuevo párrafo» se cambian por saltos, sin dejar las palabras ni la coma que les ponga el motor.
    /// El punto de la frase de antes se queda: cierra esa frase.
    static func ordenes(_ texto: String) -> String {
        var resultado = texto
        for (expresion, salto) in ordenesHabladas {
            resultado = sustituir(expresion, en: resultado, por: salto)
        }
        return resultado
    }

    // MARK: - Espacios y signos

    private static let espaciosRepetidos = regla(#"[ \t]{2,}"#)
    private static let espacioAntesDeSigno = regla(#"[ \t]+([,.;:?!…)»])"#)
    private static let espacioTrasApertura = regla(#"([¿¡(«])[ \t]+"#)
    private static let espaciosEnSalto = regla(#"[ \t]*\n[ \t]*"#)

    static func espacios(_ texto: String) -> String {
        var t = sustituir(espaciosRepetidos, en: texto, por: " ")
        t = sustituir(espacioAntesDeSigno, en: t, por: "$1")
        t = sustituir(espacioTrasApertura, en: t, por: "$1")
        t = sustituir(espaciosEnSalto, en: t, por: "\n")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Estilo

    private static let finDeFrase = regla(#"(?<=[.?!…])[ \t]+"#)

    static func aplicar(_ estilo: EstiloEscritura, a texto: String) -> String {
        guard !texto.isEmpty else { return texto }
        // Línea a línea y frase a frase: cada salto y cada punto empiezan frase.
        var lineas = texto.components(separatedBy: "\n").map { linea -> [String] in
            guard !linea.isEmpty else { return [] }
            return dividir(linea).map { frase(estilo, $0) }
        }

        // El final del texto, según el estilo.
        if let i = lineas.lastIndex(where: { !$0.isEmpty }), let ultima = lineas[i].last {
            lineas[i][lineas[i].count - 1] = cierre(estilo, ultima)
        }
        return lineas.map { $0.joined(separator: " ") }.joined(separator: "\n")
    }

    private static func dividir(_ linea: String) -> [String] {
        let rango = NSRange(linea.startIndex..., in: linea)
        var frases: [String] = []
        var desde = linea.startIndex
        for coincidencia in finDeFrase.matches(in: linea, range: rango) {
            guard let r = Range(coincidencia.range, in: linea) else { continue }
            frases.append(String(linea[desde..<r.lowerBound]))
            desde = r.upperBound
        }
        frases.append(String(linea[desde...]))
        return frases.filter { !$0.isEmpty }
    }

    private static func frase(_ estilo: EstiloEscritura, _ frase: String) -> String {
        var f = frase
        switch estilo {
        case .formal, .entusiasta:
            f = abrir(f)
            f = mayuscula(f, true)
        case .casual:
            f = sinAperturas(f)
            f = mayuscula(f, true)
        case .muyCasual:
            f = sinAperturas(f)
            f = mayuscula(f, false)
        }
        return f
    }

    private static func cierre(_ estilo: EstiloEscritura, _ frase: String) -> String {
        let acabaEnSigno = frase.last.map { ".?!…:;".contains($0) } ?? false
        switch estilo {
        case .formal:
            return acabaEnSigno ? frase : frase + "."
        case .casual, .muyCasual:
            return quitarPuntoFinal(frase)
        case .entusiasta:
            guard frase.last != "?" && frase.last != "!" else { return frase }
            let base = frase.hasSuffix(".") && !frase.hasSuffix("...") ? String(frase.dropLast()) : frase
            return base.hasPrefix("¡") ? base + "!" : "¡" + base + "!"
        }
    }

    /// Pone «¿» o «¡» al principio de la frase si acaba en «?» o «!» y no lo tiene.
    private static func abrir(_ frase: String) -> String {
        if frase.hasSuffix("?") && !frase.contains("¿") { return "¿" + frase }
        if frase.hasSuffix("!") && !frase.contains("¡") { return "¡" + frase }
        return frase
    }

    private static func sinAperturas(_ frase: String) -> String {
        frase.replacingOccurrences(of: "¿", with: "").replacingOccurrences(of: "¡", with: "")
    }

    private static func quitarPuntoFinal(_ frase: String) -> String {
        guard frase.hasSuffix("."), !frase.hasSuffix("..") else { return frase }
        return String(frase.dropLast())
    }

    /// Mayúscula o minúscula en la primera letra, tras los signos de apertura. Las siglas, como «API», no se tocan.
    private static func mayuscula(_ frase: String, _ mayus: Bool) -> String {
        guard let i = frase.firstIndex(where: { $0.isLetter }) else { return frase }
        let siguiente = frase.index(after: i)
        if !mayus, siguiente < frase.endIndex, frase[siguiente].isUppercase {
            return frase
        }
        let letra = String(frase[i])
        let nueva = mayus ? letra.uppercased() : letra.lowercased()
        return frase.replacingCharacters(in: i...i, with: nueva)
    }

    // MARK: - Expresiones

    private static func regla(_ patron: String) -> NSRegularExpression {
        // Los patrones son fijos y están probados: si uno no compila es un error de programación.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: patron, options: [.caseInsensitive])
    }

    private static func sustituir(_ expresion: NSRegularExpression, en texto: String, por plantilla: String) -> String {
        let rango = NSRange(texto.startIndex..., in: texto)
        return expresion.stringByReplacingMatches(in: texto, range: rango, withTemplate: plantilla)
    }
}
