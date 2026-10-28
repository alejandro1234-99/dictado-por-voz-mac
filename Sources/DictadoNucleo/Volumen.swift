import Foundation

public enum Volumen {
    /// Por debajo de esto es ruido de fondo; por encima de `maximo`, voz fuerte. En dB respecto al máximo del micro.
    public static let silencio: Double = -50
    public static let maximo: Double = -15

    /// Raíz de la media de los cuadrados: lo fuerte que suena un trozo de audio, de 0 a 1.
    public static func rms(_ muestras: UnsafeBufferPointer<Float>) -> Float {
        guard !muestras.isEmpty else { return 0 }
        var suma: Float = 0
        for muestra in muestras {
            suma += muestra * muestra
        }
        return (suma / Float(muestras.count)).squareRoot()
    }

    /// Pasa el volumen a una escala de 0 a 1 que se nota al hablar.
    public static func nivel(rms: Float) -> Double {
        guard rms > 0 else { return 0 }
        let decibelios = 20 * log10(Double(rms))
        return min(1, max(0, (decibelios - silencio) / (maximo - silencio)))
    }
}
