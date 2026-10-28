import AVFoundation
import Speech

/// Transcribe con el motor de voz de macOS 26, dentro del Mac. Un objeto por dictado.
///
/// El audio entra mientras se habla; al soltar solo queda cerrar. Lo que llega antes de que el
/// motor esté listo espera en una cola. `AnalyzerInputConverter` es de macOS 27, así que la
/// conversión al formato del motor se hace con `AVAudioConverter`.
final class TranscriptorApple {
    static let idiomaDeseado = Locale(identifier: "es-ES")

    private let cerrojo = NSLock()
    private var listo = false
    private var pendientes: [AVAudioPCMBuffer] = []
    private var continuacion: AsyncStream<AnalyzerInput>.Continuation?
    private var formatoMotor: AVAudioFormat?
    private var conversor: AVAudioConverter?
    private var analizador: SpeechAnalyzer?
    private var tareaResultados: Task<Void, Never>?
    private var texto = ""
    private var acabados = false

    /// Descarga el español del motor si falta. Se llama al abrir la app.
    static func prepararIdioma() async throws {
        let modulo = try await crearModulo()
        if let peticion = try await AssetInventory.assetInstallationRequest(supporting: [modulo]) {
            try await peticion.downloadAndInstall()
        }
    }

    private static func crearModulo() async throws -> SpeechTranscriber {
        guard SpeechTranscriber.isAvailable else { throw ErrorDictado.motorNoDisponible }
        guard let idioma = await SpeechTranscriber.supportedLocale(equivalentTo: idiomaDeseado) else {
            throw ErrorDictado.idiomaNoDisponible
        }
        return SpeechTranscriber(locale: idioma, preset: .transcription)
    }

    /// `palabras` son las del diccionario: el motor las tiene en cuenta para reconocerlas mejor.
    func empezar(palabras: [String] = []) async throws {
        let modulo = try await Self.crearModulo()
        let analizador = SpeechAnalyzer(modules: [modulo])
        if !palabras.isEmpty {
            let contexto = AnalysisContext()
            contexto.contextualStrings[.general] = palabras
            do {
                try await analizador.setContext(contexto)
            } catch {
                NSLog("Dictado: el motor de voz no aceptó el diccionario: \(error.localizedDescription)")
            }
        }
        let formato = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [modulo])
        let (secuencia, continuacion) = AsyncStream.makeStream(of: AnalyzerInput.self)

        tareaResultados = Task { [weak self] in
            do {
                for try await resultado in modulo.results where resultado.isFinal {
                    self?.anadirTexto(String(resultado.text.characters))
                }
            } catch {
                NSLog("Dictado: el motor de voz devolvió un error: \(error.localizedDescription)")
            }
            self?.marcarAcabados()
        }
        try await analizador.start(inputSequence: secuencia)
        activar(analizador: analizador, formato: formato, continuacion: continuacion)
    }

    // El cerrojo solo se coge en funciones síncronas: NSLock no se puede usar desde código async.

    private func activar(
        analizador: SpeechAnalyzer,
        formato: AVAudioFormat?,
        continuacion: AsyncStream<AnalyzerInput>.Continuation
    ) {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        self.analizador = analizador
        self.formatoMotor = formato
        self.continuacion = continuacion
        listo = true
        for buffer in pendientes { enviar(buffer) }
        pendientes.removeAll()
    }

    private func cerrarEntrada() -> (AsyncStream<AnalyzerInput>.Continuation?, SpeechAnalyzer?) {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        let abierta = (continuacion, analizador)
        continuacion = nil
        listo = false
        pendientes.removeAll()
        return abierta
    }

    private func textoFinal() -> String {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return texto.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lo llama el grabador desde el hilo de audio con cada trozo.
    func anadir(_ buffer: AVAudioPCMBuffer) {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        if listo {
            enviar(buffer)
        } else if let copia = Self.copiar(buffer) {
            pendientes.append(copia)
        }
    }

    /// Cierra la entrada y devuelve el texto final. Como mucho espera 2 s a los últimos resultados.
    func terminar() async throws -> String {
        let (continuacion, analizador) = cerrarEntrada()
        continuacion?.finish()
        if let analizador {
            try await analizador.finalizeAndFinishThroughEndOfInput()
        }
        // Los resultados pueden tardar un poco en llegar; no se espera a la tarea, que podría
        // no enterarse de que se cancela, sino a que avise de que ha acabado.
        let limite = Date().addingTimeInterval(2)
        while !resultadosAcabados() && Date() < limite {
            try? await Task.sleep(for: .milliseconds(20))
        }
        tareaResultados?.cancel()
        return textoFinal()
    }

    private func resultadosAcabados() -> Bool {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        return acabados
    }

    private func marcarAcabados() {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        acabados = true
    }

    func cancelar() async {
        let (continuacion, analizador) = cerrarEntrada()
        continuacion?.finish()
        await analizador?.cancelAndFinishNow()
        tareaResultados?.cancel()
    }

    private func anadirTexto(_ nuevo: String) {
        cerrojo.lock()
        defer { cerrojo.unlock() }
        if !texto.isEmpty && !texto.hasSuffix(" ") && !nuevo.hasPrefix(" ") {
            texto += " "
        }
        texto += nuevo
    }

    /// Con el cerrojo cogido: convierte el trozo al formato del motor y lo mete en la entrada.
    private func enviar(_ buffer: AVAudioPCMBuffer) {
        guard let continuacion else { return }
        guard let formatoMotor, buffer.format != formatoMotor else {
            if let copia = Self.copiar(buffer) {
                continuacion.yield(AnalyzerInput(buffer: copia))
            }
            return
        }
        if conversor == nil || conversor?.inputFormat != buffer.format {
            conversor = AVAudioConverter(from: buffer.format, to: formatoMotor)
        }
        guard let conversor else { return }

        let proporcion = formatoMotor.sampleRate / buffer.format.sampleRate
        let capacidad = AVAudioFrameCount((Double(buffer.frameLength) * proporcion).rounded(.up)) + 64
        guard let salida = AVAudioPCMBuffer(pcmFormat: formatoMotor, frameCapacity: capacidad) else { return }

        var entregado = false
        var error: NSError?
        let estado = conversor.convert(to: salida, error: &error) { _, estadoEntrada in
            if entregado {
                estadoEntrada.pointee = .noDataNow
                return nil
            }
            entregado = true
            estadoEntrada.pointee = .haveData
            return buffer
        }
        guard estado != .error, salida.frameLength > 0 else { return }
        continuacion.yield(AnalyzerInput(buffer: salida))
    }

    /// El motor de audio puede reutilizar sus trozos: lo que se guarda para después va copiado.
    private static func copiar(_ origen: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copia = AVAudioPCMBuffer(pcmFormat: origen.format, frameCapacity: origen.frameLength) else {
            return nil
        }
        copia.frameLength = origen.frameLength
        let desde = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: origen.audioBufferList))
        let hacia = UnsafeMutableAudioBufferListPointer(copia.mutableAudioBufferList)
        for (a, b) in zip(desde, hacia) {
            if let datosA = a.mData, let datosB = b.mData {
                memcpy(datosB, datosA, Int(min(a.mDataByteSize, b.mDataByteSize)))
            }
        }
        return copia
    }
}
