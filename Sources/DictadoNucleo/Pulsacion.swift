import Foundation

public enum Pulsacion {
    /// Por debajo de esto se toma como un toque sin querer y no se dicta nada.
    public static let minima: TimeInterval = 0.3

    public static func cuenta(duracion: TimeInterval) -> Bool {
        duracion >= minima
    }
}
