import AVFoundation
import DictadoNucleo

/// Abre el micro al pulsar y lo cierra al soltar. Guarda el audio en un archivo y lo pasa al motor.
/// Un motor de audio nuevo por dictado: así aguanta cambios de micro, como conectar unos AirPods.
final class Grabador {
    var alRecibir: ((AVAudioPCMBuffer) -> Void)?
    /// El volumen de cada trozo, de 0 a 1, para la bola. Llega desde el hilo de audio.
    var alMedir: ((Double) -> Void)?

    private var motor: AVAudioEngine?
    private var archivo: AVAudioFile?

    func empezar(guardandoEn url: URL) throws {
        let motor = AVAudioEngine()
        let entrada = motor.inputNode
        let formato = entrada.outputFormat(forBus: 0)
        guard formato.sampleRate > 0, formato.channelCount > 0 else {
            throw ErrorDictado.sinMicro
        }

        archivo = try AVAudioFile(
            forWriting: url,
            settings: formato.settings,
            commonFormat: formato.commonFormat,
            interleaved: formato.isInterleaved
        )
        self.motor = motor

        entrada.installTap(onBus: 0, bufferSize: 2048, format: formato) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.archivo?.write(from: buffer)
            self.alRecibir?(buffer)
            if let alMedir = self.alMedir, let canal = buffer.floatChannelData?[0] {
                let muestras = UnsafeBufferPointer(start: canal, count: Int(buffer.frameLength))
                alMedir(Volumen.nivel(rms: Volumen.rms(muestras)))
            }
        }
        motor.prepare()
        try motor.start()
    }

    /// Cierra el micro y el archivo. Devuelve los segundos grabados.
    func parar() -> Double {
        motor?.inputNode.removeTap(onBus: 0)
        motor?.stop()
        let segundos = archivo.map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0
        motor = nil
        archivo = nil
        return segundos
    }
}
