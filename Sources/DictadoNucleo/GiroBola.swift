import Foundation

/// El movimiento de la bola del dictado, fotograma a fotograma.
///
/// El giro se va sumando en vez de calcularse con la hora: así, al acelerar, la bola no da un salto.
/// La energía sube deprisa cuando se habla y baja despacio, como la aguja de un vúmetro.
public final class GiroBola {
    /// Vueltas por segundo, en radianes, con la bola en calma y con la voz más fuerte.
    public static let velocidadCalma: Double = 0.8
    public static let velocidadVoz: Double = 6
    /// Un fotograma no cuenta más que esto, para que la bola no salte si la ventana estuvo parada.
    public static let pasoMaximo: TimeInterval = 0.1

    public private(set) var fase: Double = 0
    public private(set) var energia: Double = 0
    private var ultima: Date?

    public init() {}

    public func avanzar(a fecha: Date, nivel: Double) {
        let paso = ultima.map { min(max(fecha.timeIntervalSince($0), 0), Self.pasoMaximo) } ?? 0
        ultima = fecha
        let objetivo = min(1, max(0, nivel))
        let rapidez: Double = objetivo > energia ? 18 : 4
        energia += (objetivo - energia) * min(1, paso * rapidez)
        fase += paso * (Self.velocidadCalma + (Self.velocidadVoz - Self.velocidadCalma) * energia)
    }
}
