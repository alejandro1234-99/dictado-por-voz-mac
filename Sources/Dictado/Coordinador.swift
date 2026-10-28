import AppKit
import DictadoNucleo

/// El bucle del dictado: pulsar, grabar, transcribir y pegar. Vive en el hilo principal.
final class Coordinador {
    private let tecla = Tecla()
    private let pildora = Pildora()
    private let insertador = Insertador()
    private let almacen = Almacen.compartido

    private var grabador: Grabador?
    private var transcriptor: TranscriptorApple?
    private var tareaInicio: Task<Void, Error>?
    private var idActual: String?
    private var rutaAudio: URL?
    private var inicio: Date?
    /// La app que estaba delante al pulsar: marca el estilo y dónde se escribe.
    private var appDelante: String?
    /// Cómo acabó el último dictado y en qué app, por si la app no deja leer qué hay antes del cursor.
    private var ultimo: (app: String?, ultimaLetra: Character?, cuando: Date)?
    /// Mientras se transcribe el anterior no se empieza otro.
    private var ocupado = false

    /// La tecla necesita Accesibilidad: se arranca en cuanto está concedida.
    func arrancarSiSePuede() {
        guard !tecla.activa, Permisos.accesibilidad else { return }
        tecla.alPulsar = { [weak self] in self?.pulsar() }
        tecla.alSoltar = { [weak self] in self?.soltar() }
        tecla.alCancelar = { [weak self] in self?.descartar() }
        if !tecla.arrancar() {
            NSLog("Dictado: no se pudo escuchar la tecla de dictado")
        }
    }

    /// Otra tecla a la vez que el atajo: era un atajo del Mac, no un dictado. Se tira sin avisar.
    private func descartar() {
        guard let grabador, let transcriptor, let id = idActual else { return }
        _ = grabador.parar()
        self.grabador = nil
        pildora.ocultar()
        Task { await transcriptor.cancelar() }
        almacen?.borrar(id: id, rutaAudio: rutaAudio)
        limpiar()
    }

    private func pulsar() {
        guard !ocupado, grabador == nil, Permisos.micro else { return }

        let id = UUID().uuidString
        let carpeta = almacen?.carpetaAudio ?? FileManager.default.temporaryDirectory
        let ruta = carpeta.appendingPathComponent("\(id).caf")
        let transcriptor = TranscriptorApple()
        let grabador = Grabador()
        grabador.alRecibir = { [weak transcriptor] buffer in transcriptor?.anadir(buffer) }
        let nivel = pildora.nivel
        grabador.alMedir = { nivel.poner($0) }

        do {
            try grabador.empezar(guardandoEn: ruta)
        } catch {
            NSLog("Dictado: no se pudo abrir el micro: \(error.localizedDescription)")
            return
        }

        self.grabador = grabador
        self.transcriptor = transcriptor
        idActual = id
        rutaAudio = ruta
        inicio = Date()
        let app = NSWorkspace.shared.frontmostApplication
        appDelante = app?.bundleIdentifier
        ContextoCursor.prepararApp(app)
        almacen?.crear(id: id, app: app, rutaAudio: ruta.path)
        let palabras = Diccionario.palabrasParaElMotor(DatosApp.compartido.diccionario)
        tareaInicio = Task { try await transcriptor.empezar(palabras: palabras) }
        pildora.mostrar()
    }

    private func soltar() {
        guard let grabador, let transcriptor, let id = idActual, let inicio else { return }

        // Lo primero, cerrar el micro.
        let segundos = grabador.parar()
        self.grabador = nil
        pildora.calmar()

        let ruta = rutaAudio
        guard Pulsacion.cuenta(duracion: Date().timeIntervalSince(inicio)) else {
            pildora.ocultar()
            Task { await transcriptor.cancelar() }
            almacen?.borrar(id: id, rutaAudio: ruta)
            limpiar()
            return
        }

        ocupado = true
        almacen?.cambiarEstado(id: id, estado: "transcribiendo")
        // Red de seguridad: si el motor se queda colgado, la tecla vuelve a funcionar a los 15 s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.ocupado, self.idActual == id else { return }
            NSLog("Dictado: la transcripción tardó más de 15 s; se libera la tecla")
            self.ocupado = false
            self.pildora.ocultar()
        }
        let tareaInicio = self.tareaInicio
        let soltadoEn = Date()
        let app = appDelante

        Task { @MainActor in
            do {
                try await tareaInicio?.value
                let texto = try await transcriptor.terminar()
                let ms = Int(Date().timeIntervalSince(soltadoEn) * 1000)
                let estilo = Ajustes.estilos[TipoApp.de(bundle: app)]
                let corregido = Diccionario.aplicar(DatosApp.compartido.diccionario, a: texto)
                let preparado = Texto.preparar(corregido, estilo: estilo)
                if preparado.isEmpty {
                    self.almacen?.borrar(id: id, rutaAudio: ruta)
                } else {
                    let escrito = Texto.unir(preparado, tras: self.caracterAnterior(app: app))
                    self.insertador.escribir(escrito, palabraAPalabra: Ajustes.escrituraProgresiva)
                    self.ultimo = (app, escrito.last, Date())
                    self.almacen?.terminar(
                        id: id, estado: "pegado", texto: texto, textoLimpio: escrito, segundos: segundos, ms: ms, error: nil
                    )
                    NotificationCenter.default.post(name: .dictadoGuardado, object: nil)
                }
            } catch {
                NSLog("Dictado: la transcripción falló: \(error.localizedDescription)")
                self.almacen?.terminar(
                    id: id, estado: "fallido", texto: nil, segundos: segundos, ms: nil,
                    error: error.localizedDescription
                )
            }
            self.pildora.ocultar()
            self.ocupado = false
            self.limpiar()
        }
    }

    /// Lo que hay antes del cursor. Si la app no deja leerlo, lo que acabó el último dictado en esa misma app, si fue
    /// hace menos de 10 minutos; si no, nada, y el texto se escribe tal cual.
    private func caracterAnterior(app: String?) -> Character? {
        switch ContextoCursor.leer() {
        case .caracter(let letra):
            return letra
        case .alPrincipio:
            return nil
        case .desconocido:
            guard let ultimo, ultimo.app == app, Date().timeIntervalSince(ultimo.cuando) < 600 else { return nil }
            return ultimo.ultimaLetra
        }
    }

    private func limpiar() {
        appDelante = nil
        transcriptor = nil
        tareaInicio = nil
        idActual = nil
        rutaAudio = nil
        inicio = nil
    }
}
