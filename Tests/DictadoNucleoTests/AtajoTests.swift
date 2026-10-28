import DictadoNucleo
import Foundation
import Testing

private let espacio: UInt16 = 49
private let k: UInt16 = 40
private let f5: UInt16 = 96
private let flechaIzquierda: UInt16 = 123

@Suite("Qué atajos valen y cómo se ven")
struct AtajoTests {
    @Test("Fn y dos modificadores valen; uno solo, no")
    func validacionModificadores() {
        #expect(Atajo.fn.problema == nil)
        #expect(Atajo(modificadores: [.control, .opcion]).problema == nil)
        #expect(Atajo(modificadores: .opcion).problema == .unaSolaModificadora)
        #expect(Atajo(modificadores: .comando).problema == .unaSolaModificadora)
        #expect(Atajo(modificadores: .mayusculas).problema == .unaSolaModificadora)
    }

    @Test("Una tecla normal necesita modificadores; una tecla F, no")
    func validacionTecla() {
        #expect(Atajo(modificadores: [], tecla: k, nombreTecla: "K").problema == .sinModificadores)
        #expect(Atajo(modificadores: .opcion, tecla: espacio, nombreTecla: "Espacio").problema == nil)
        #expect(Atajo(modificadores: [], tecla: f5, nombreTecla: "F5").problema == nil)
    }

    @Test("El nombre usa los símbolos de macOS en su orden")
    func nombres() {
        #expect(Atajo.fn.nombre == "Fn 🌐")
        #expect(Atajo(modificadores: [.opcion, .control]).nombre == "⌃⌥")
        #expect(Atajo(modificadores: [.comando, .mayusculas], tecla: k, nombreTecla: "K").nombre == "⇧⌘K")
        #expect(Atajo(modificadores: .opcion, tecla: espacio, nombreTecla: "Espacio").nombre == "⌥ Espacio")
        #expect(Atajo(modificadores: [], tecla: f5, nombreTecla: "F5").nombre == "F5")
    }

    @Test("Se guarda y se recupera igual")
    func guardar() throws {
        let atajo = Atajo(modificadores: [.control, .comando], tecla: k, nombreTecla: "K")
        let datos = try JSONEncoder().encode(atajo)
        #expect(try JSONDecoder().decode(Atajo.self, from: datos) == atajo)
    }
}

@Suite("Grabar un atajo nuevo")
struct GrabacionAtajoTests {
    @Test("Pulsar ⌃ y ⌥ y soltarlos graba ⌃⌥")
    func soloModificadores() {
        var grabacion = GrabacionAtajo()
        #expect(grabacion.recibir(.modificadores(.control)) == nil)
        #expect(grabacion.recibir(.modificadores([.control, .opcion])) == nil)
        #expect(grabacion.recibir(.modificadores(.opcion)) == nil)
        #expect(grabacion.recibir(.modificadores([])) == .listo(Atajo(modificadores: [.control, .opcion])))
    }

    @Test("Fn sola se graba como Fn")
    func fnSola() {
        var grabacion = GrabacionAtajo()
        _ = grabacion.recibir(.modificadores(.fn))
        #expect(grabacion.recibir(.modificadores([])) == .listo(.fn))
    }

    @Test("Modificadores y una tecla graban la tecla con su nombre")
    func conTecla() {
        var grabacion = GrabacionAtajo()
        _ = grabacion.recibir(.modificadores(.opcion))
        let resultado = grabacion.recibir(.abajo(tecla: espacio, modificadores: .opcion, repetida: false), nombreTecla: " ")
        #expect(resultado == .listo(Atajo(modificadores: .opcion, tecla: espacio, nombreTecla: "Espacio")))
    }

    @Test("Una letra se nombra con lo que escribe el teclado, en mayúscula")
    func letra() {
        var grabacion = GrabacionAtajo()
        let resultado = grabacion.recibir(.abajo(tecla: k, modificadores: [.control, .comando], repetida: false), nombreTecla: "k")
        #expect(resultado == .listo(Atajo(modificadores: [.control, .comando], tecla: k, nombreTecla: "K")))
    }

    @Test("Las flechas llevan Fn por su cuenta: no se guarda")
    func flechaSinFn() {
        var grabacion = GrabacionAtajo()
        let resultado = grabacion.recibir(.abajo(tecla: flechaIzquierda, modificadores: [.opcion, .fn], repetida: false))
        #expect(resultado == .listo(Atajo(modificadores: .opcion, tecla: flechaIzquierda, nombreTecla: "←")))
    }

    @Test("Esc sin modificadores cancela; con ellos, es un atajo")
    func escape() {
        var grabacion = GrabacionAtajo()
        #expect(grabacion.recibir(.abajo(tecla: Teclas.escape, modificadores: [], repetida: false)) == .cancelado)
        let conModificadores = grabacion.recibir(.abajo(tecla: Teclas.escape, modificadores: [.control, .opcion], repetida: false))
        #expect(conModificadores == .listo(Atajo(modificadores: [.control, .opcion], tecla: Teclas.escape, nombreTecla: "Esc")))
    }

    @Test("Una sola modificadora o una letra sola se rechazan, y se puede volver a probar")
    func rechazos() {
        var grabacion = GrabacionAtajo()
        _ = grabacion.recibir(.modificadores(.comando))
        #expect(grabacion.recibir(.modificadores([])) == .rechazado(.unaSolaModificadora))
        #expect(grabacion.recibir(.abajo(tecla: k, modificadores: [], repetida: false), nombreTecla: "k") == .rechazado(.sinModificadores))
        _ = grabacion.recibir(.modificadores(.control))
        _ = grabacion.recibir(.modificadores([.control, .mayusculas]))
        #expect(grabacion.recibir(.modificadores([])) == .listo(Atajo(modificadores: [.control, .mayusculas])))
    }
}

@Suite("Dictar con el atajo")
struct DetectorAtajoTests {
    private let empezar = DetectorAtajo.Respuesta(accion: .empezar, tragar: false)
    private let terminar = DetectorAtajo.Respuesta(accion: .terminar, tragar: false)
    private let nada = DetectorAtajo.Respuesta(accion: nil, tragar: false)

    @Test("Fn: pulsar empieza y soltar termina")
    func fn() {
        var detector = DetectorAtajo(atajo: .fn)
        #expect(detector.recibir(.modificadores(.fn)) == empezar)
        #expect(detector.recibir(.modificadores([])) == terminar)
    }

    @Test("Fn con ⌘ es otro atajo y no dicta")
    func fnConComando() {
        var detector = DetectorAtajo(atajo: .fn)
        #expect(detector.recibir(.modificadores([.fn, .comando])) == nada)
        #expect(detector.recibir(.modificadores([])) == nada)
    }

    @Test("⌃⌥: empieza con los dos, sigue aunque se añada ⌘ y termina al soltar uno")
    func dosModificadores() {
        var detector = DetectorAtajo(atajo: Atajo(modificadores: [.control, .opcion]))
        #expect(detector.recibir(.modificadores(.opcion)) == nada)
        #expect(detector.recibir(.modificadores([.control, .opcion])) == empezar)
        #expect(detector.recibir(.modificadores([.control, .opcion, .comando])) == nada)
        #expect(detector.recibir(.modificadores(.control)) == terminar)
    }

    @Test("Otra tecla con el atajo de modificadores cancela, sin tragársela")
    func cancelar() {
        var detector = DetectorAtajo(atajo: Atajo(modificadores: [.control, .opcion]))
        _ = detector.recibir(.modificadores([.control, .opcion]))
        #expect(detector.recibir(.abajo(tecla: k, modificadores: [.control, .opcion], repetida: false))
            == DetectorAtajo.Respuesta(accion: .cancelar, tragar: false))
        #expect(!detector.pulsado)
    }

    @Test("Tras cancelar no vuelve a empezar hasta soltar el atajo")
    func bloqueoTrasCancelar() {
        var detector = DetectorAtajo(atajo: Atajo(modificadores: [.control, .opcion]))
        _ = detector.recibir(.modificadores([.control, .opcion]))
        _ = detector.recibir(.abajo(tecla: k, modificadores: [.control, .opcion], repetida: false))
        #expect(detector.recibir(.modificadores([.control, .opcion, .comando])) == nada)
        #expect(detector.recibir(.modificadores([.control, .opcion])) == nada)
        #expect(detector.recibir(.modificadores([])) == nada)
        #expect(detector.recibir(.modificadores([.control, .opcion])) == empezar)
    }

    @Test("⌥ Espacio: la tecla se queda aquí al pulsar, al repetir y al soltar")
    func conTecla() {
        var detector = DetectorAtajo(atajo: Atajo(modificadores: .opcion, tecla: espacio, nombreTecla: "Espacio"))
        #expect(detector.recibir(.modificadores(.opcion)) == nada)
        #expect(detector.recibir(.abajo(tecla: espacio, modificadores: .opcion, repetida: false))
            == DetectorAtajo.Respuesta(accion: .empezar, tragar: true))
        #expect(detector.recibir(.abajo(tecla: espacio, modificadores: .opcion, repetida: true))
            == DetectorAtajo.Respuesta(accion: nil, tragar: true))
        #expect(detector.recibir(.arriba(tecla: espacio, modificadores: .opcion))
            == DetectorAtajo.Respuesta(accion: .terminar, tragar: true))
    }

    @Test("⌥ Espacio: soltar ⌥ primero termina, y el Espacio que se suelta después tampoco llega")
    func soltarModificadorPrimero() {
        var detector = DetectorAtajo(atajo: Atajo(modificadores: .opcion, tecla: espacio, nombreTecla: "Espacio"))
        _ = detector.recibir(.abajo(tecla: espacio, modificadores: .opcion, repetida: false))
        #expect(detector.recibir(.modificadores([])) == terminar)
        #expect(detector.recibir(.arriba(tecla: espacio, modificadores: []))
            == DetectorAtajo.Respuesta(accion: nil, tragar: true))
    }

    @Test("Espacio sin ⌥, u otra tecla, pasan a la app como siempre")
    func teclasAjenas() {
        var detector = DetectorAtajo(atajo: Atajo(modificadores: .opcion, tecla: espacio, nombreTecla: "Espacio"))
        #expect(detector.recibir(.abajo(tecla: espacio, modificadores: [], repetida: false)) == nada)
        #expect(detector.recibir(.arriba(tecla: espacio, modificadores: [])) == nada)
        #expect(detector.recibir(.abajo(tecla: k, modificadores: .opcion, repetida: false)) == nada)
    }

    @Test("Con una tecla F, el Fn que macOS añade solo no estorba")
    func teclaF() {
        var detector = DetectorAtajo(atajo: Atajo(modificadores: [], tecla: f5, nombreTecla: "F5"))
        #expect(detector.recibir(.abajo(tecla: f5, modificadores: .fn, repetida: false))
            == DetectorAtajo.Respuesta(accion: .empezar, tragar: true))
        #expect(detector.recibir(.arriba(tecla: f5, modificadores: .fn))
            == DetectorAtajo.Respuesta(accion: .terminar, tragar: true))
    }
}
