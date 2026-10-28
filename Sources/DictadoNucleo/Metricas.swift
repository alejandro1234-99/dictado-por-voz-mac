import Foundation

/// Lo que hace falta de cada dictado para las métricas.
public struct RegistroDictado: Equatable, Sendable {
    public var fecha: Date
    public var palabras: Int
    public var segundosAudio: Double

    public init(fecha: Date, palabras: Int, segundosAudio: Double) {
        self.fecha = fecha
        self.palabras = palabras
        self.segundosAudio = segundosAudio
    }
}

/// Las palabras de un día, para el gráfico de los últimos 7.
public struct PalabrasDelDia: Equatable, Sendable {
    public var dia: Date
    public var palabras: Int
}

/// Las cifras de Inicio, sacadas del historial que se guarda en el Mac.
public struct Metricas: Equatable, Sendable {
    /// A esta velocidad se escribe a mano, de media, con el teclado: la base del tiempo ahorrado.
    public static let palabrasPorMinutoAMano = 40.0

    public var hoy = 0
    public var dictadosHoy = 0
    public var semana = 0
    public var total = 0
    public var palabrasPorMinuto = 0
    public var diasSeguidos = 0
    public var segundosAhorrados = 0.0
    /// Del más antiguo a hoy.
    public var ultimos7Dias: [PalabrasDelDia] = []

    public init() {}

    /// `calendario` decide dónde empieza la semana y los días: en España, el lunes y la hora local.
    public static func calcular(_ registros: [RegistroDictado], hoy ahora: Date = Date(), calendario: Calendar) -> Metricas {
        var m = Metricas()
        let hoy = calendario.startOfDay(for: ahora)
        let inicioSemana = calendario.dateInterval(of: .weekOfYear, for: ahora)?.start ?? hoy

        var porDia: [Date: Int] = [:]
        var palabrasConAudio = 0
        var segundosConAudio = 0.0
        var segundosHablando = 0.0
        for registro in registros where registro.palabras > 0 {
            let dia = calendario.startOfDay(for: registro.fecha)
            porDia[dia, default: 0] += registro.palabras
            m.total += registro.palabras
            if dia == hoy {
                m.hoy += registro.palabras
                m.dictadosHoy += 1
            }
            if registro.fecha >= inicioSemana && registro.fecha <= ahora {
                m.semana += registro.palabras
            }
            if registro.segundosAudio > 0 {
                palabrasConAudio += registro.palabras
                segundosConAudio += registro.segundosAudio
            }
            segundosHablando += max(0, registro.segundosAudio)
        }

        if segundosConAudio > 0 {
            m.palabrasPorMinuto = Int((Double(palabrasConAudio) / (segundosConAudio / 60)).rounded())
        }
        let segundosAMano = Double(m.total) / palabrasPorMinutoAMano * 60
        m.segundosAhorrados = max(0, segundosAMano - segundosHablando)

        // Días seguidos dictando hasta hoy. Si hoy aún no se ha dictado, la racha sigue viva desde ayer.
        var dia = porDia[hoy] != nil ? hoy : (calendario.date(byAdding: .day, value: -1, to: hoy) ?? hoy)
        while porDia[dia] != nil {
            m.diasSeguidos += 1
            guard let anterior = calendario.date(byAdding: .day, value: -1, to: dia) else { break }
            dia = anterior
        }

        m.ultimos7Dias = (0..<7).reversed().compactMap { atras in
            guard let dia = calendario.date(byAdding: .day, value: -atras, to: hoy) else { return nil }
            return PalabrasDelDia(dia: dia, palabras: porDia[dia] ?? 0)
        }
        return m
    }

    /// Cifras con punto de miles, como en España, también las de cuatro cifras: 1.284.
    public static func cifra(_ numero: Int) -> String {
        let signo = numero < 0 ? "-" : ""
        var digitos = String(abs(numero))
        var grupos: [String] = []
        while digitos.count > 3 {
            grupos.insert(String(digitos.suffix(3)), at: 0)
            digitos.removeLast(3)
        }
        grupos.insert(digitos, at: 0)
        return signo + grupos.joined(separator: ".")
    }

    /// «4 h 10 min», «25 min» o «40 s».
    public static func tiempo(_ segundos: Double) -> String {
        let total = Int(segundos.rounded())
        let horas = total / 3600
        let minutos = (total % 3600) / 60
        if horas > 0 { return minutos > 0 ? "\(horas) h \(minutos) min" : "\(horas) h" }
        if minutos > 0 { return "\(minutos) min" }
        return "\(total) s"
    }
}
