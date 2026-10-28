import DictadoNucleo
import Testing

@Suite("Órdenes habladas: nueva línea y nuevo párrafo")
struct OrdenesTests {
    @Test(
        "Se cambian por saltos y las palabras no quedan en el texto",
        arguments: [
            ("Hola nueva línea qué tal", "Hola\nQué tal."),
            ("Hola, nueva línea, qué tal.", "Hola\nQué tal."),
            ("Hola. Nueva línea. Qué tal.", "Hola.\nQué tal."),
            ("Primero nuevo párrafo segundo", "Primero\n\nSegundo."),
            ("Primero. Nuevo párrafo. Segundo.", "Primero.\n\nSegundo."),
            ("Uno nueva linea dos", "Uno\nDos."),
            ("Uno NUEVA LÍNEA dos", "Uno\nDos."),
            ("Lista nueva línea leche nueva línea pan", "Lista\nLeche\nPan."),
            ("Asunto nuevo párrafo Hola, Marta nueva línea te escribo", "Asunto\n\nHola, Marta\nTe escribo."),
            ("Una línea nueva no es una orden", "Una línea nueva no es una orden."),
            ("Nueva línea al principio", "Al principio."),
        ]
    )
    func ordenes(entrada: String, esperado: String) {
        #expect(Texto.preparar(entrada, estilo: .formal) == esperado)
    }
}

@Suite("Espacios, signos y mayúsculas")
struct SignosTests {
    @Test(
        "El texto empieza en mayúscula, sin espacios dobles ni espacios antes de los signos, y abre «¿» y «¡»",
        arguments: [
            ("hola qué tal", "Hola qué tal."),
            ("hola  qué   tal", "Hola qué tal."),
            ("hola , qué tal .", "Hola, qué tal."),
            ("vienes mañana ?", "¿Vienes mañana?"),
            ("qué bien !", "¡Qué bien!"),
            ("¿ vienes mañana?", "¿Vienes mañana?"),
            ("hola. vienes mañana? genial", "Hola. ¿Vienes mañana? Genial."),
            ("uno : dos ; tres", "Uno: dos; tres."),
            ("  con espacios al principio y al final  ", "Con espacios al principio y al final."),
            ("la API va bien", "La API va bien."),
            ("ya acabé...", "Ya acabé..."),
            ("¿Ya está?", "¿Ya está?"),
        ]
    )
    func signos(entrada: String, esperado: String) {
        #expect(Texto.preparar(entrada, estilo: .formal) == esperado)
    }
}

@Suite("Estilos de escritura")
struct EstilosTests {
    private let frase = "hola, quedamos mañana? te paso el documento"

    @Test("Formal: mayúsculas, signos de apertura y punto final")
    func formal() {
        #expect(Texto.preparar(frase, estilo: .formal) == "¿Hola, quedamos mañana? Te paso el documento.")
    }

    @Test("Casual: sin signos de apertura ni punto final")
    func casual() {
        #expect(Texto.preparar(frase, estilo: .casual) == "Hola, quedamos mañana? Te paso el documento")
    }

    @Test("Muy casual: además, sin mayúscula al empezar")
    func muyCasual() {
        #expect(Texto.preparar(frase, estilo: .muyCasual) == "hola, quedamos mañana? te paso el documento")
    }

    @Test("Entusiasta: acaba con exclamación")
    func entusiasta() {
        #expect(Texto.preparar(frase, estilo: .entusiasta) == "¿Hola, quedamos mañana? ¡Te paso el documento!")
    }

    @Test(
        "Cada estilo con más frases",
        arguments: [
            ("¿Vienes a comer?", EstiloEscritura.casual, "Vienes a comer?"),
            ("¡Qué bien!", EstiloEscritura.casual, "Qué bien!"),
            ("Vale. Hablamos luego.", EstiloEscritura.casual, "Vale. Hablamos luego"),
            ("Vale. Hablamos luego.", EstiloEscritura.muyCasual, "vale. hablamos luego"),
            ("API caída.", EstiloEscritura.muyCasual, "API caída"),
            ("Gracias por todo.", EstiloEscritura.entusiasta, "¡Gracias por todo!"),
            ("¿Lo tienes?", EstiloEscritura.entusiasta, "¿Lo tienes?"),
            ("Hola nueva línea gracias", EstiloEscritura.casual, "Hola\nGracias"),
            ("Ya acabé...", EstiloEscritura.casual, "Ya acabé..."),
            ("perfecto", EstiloEscritura.formal, "Perfecto."),
        ]
    )
    func masFrases(entrada: String, estilo: EstiloEscritura, esperado: String) {
        #expect(Texto.preparar(entrada, estilo: estilo) == esperado)
    }

    @Test("Un texto vacío se queda vacío")
    func vacio() {
        for estilo in EstiloEscritura.allCases {
            #expect(Texto.preparar("   ", estilo: estilo) == "")
        }
    }
}

@Suite("Seguir escribiendo tras un dictado")
struct UnirTests {
    @Test(
        "Tras un punto o una letra se añade un espacio; tras un espacio, un salto o al empezar, no",
        arguments: [
            (Character("."), "Siguiente frase.", " Siguiente frase."),
            (Character("?"), "Vale.", " Vale."),
            (Character("a"), "y sigo.", " y sigo."),
            (Character(","), "y sigo.", " y sigo."),
            (Character(" "), "Sigo.", "Sigo."),
            (Character("\n"), "Sigo.", "Sigo."),
            (Character("¿"), "Vienes?", "Vienes?"),
            (Character("("), "nota)", "nota)"),
            (Character("a"), ", y sigo", ", y sigo"),
        ]
    )
    func unir(anterior: Character, texto: String, esperado: String) {
        #expect(Texto.unir(texto, tras: anterior) == esperado)
    }

    @Test("Si no se sabe qué hay antes, o el campo está vacío, no se añade nada")
    func sinSaber() {
        #expect(Texto.unir("Hola.", tras: nil) == "Hola.")
        #expect(Texto.unir("", tras: ".") == "")
    }
}

@Suite("Escribir palabra a palabra")
struct TrozosTests {
    @Test("Cada palabra va con su espacio y, juntas, dan el texto entero")
    func palabras() {
        let texto = "¿Quedamos mañana? Te paso el documento."
        let trozos = Texto.trozos(texto)
        #expect(trozos == ["¿Quedamos ", "mañana? ", "Te ", "paso ", "el ", "documento."])
        #expect(trozos.joined() == texto)
    }

    @Test("Las palabras largas van en trozos de 20 sin partir letras")
    func largas() {
        let texto = "supercalifragilisticoespialidoso 👍🏽 ok"
        let trozos = Texto.trozos(texto)
        #expect(trozos.allSatisfy { $0.utf16.count <= 20 })
        #expect(trozos.joined() == texto)
    }
}

@Suite("Estilo según la app")
struct TipoAppTests {
    @Test("Las apps se reconocen por su identificador, sin mayúsculas que importen")
    func tipos() {
        #expect(TipoApp.de(bundle: "net.whatsapp.WhatsApp") == .personal)
        #expect(TipoApp.de(bundle: "com.tinyspeck.slackmacgap") == .trabajo)
        #expect(TipoApp.de(bundle: "com.apple.mail") == .email)
        #expect(TipoApp.de(bundle: "com.microsoft.VSCode") == .otras)
        #expect(TipoApp.de(bundle: nil) == .otras)
    }

    @Test("De serie, Casual en lo personal y Formal en lo demás")
    func serie() {
        let estilos = EstilosPorApp.estandar
        #expect(estilos[.personal] == .casual)
        #expect(estilos[.trabajo] == .formal)
        #expect(estilos[.email] == .formal)
        #expect(estilos[.otras] == .formal)
    }
}
