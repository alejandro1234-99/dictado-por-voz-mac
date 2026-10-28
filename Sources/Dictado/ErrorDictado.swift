import Foundation

enum ErrorDictado: LocalizedError {
    case sinMicro
    case motorNoDisponible
    case idiomaNoDisponible
    case almacen(String)

    var errorDescription: String? {
        switch self {
        case .sinMicro: return "No hay ningún micrófono disponible."
        case .motorNoDisponible: return "El motor de voz de macOS no está disponible en este Mac."
        case .idiomaNoDisponible: return "El motor de voz de macOS no tiene el español."
        case .almacen(let detalle): return "No se pudo guardar el dictado: \(detalle)"
        }
    }
}
