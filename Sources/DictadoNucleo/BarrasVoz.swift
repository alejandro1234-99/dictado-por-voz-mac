import Foundation

/// Las barras de las cápsulas: suben con la voz, más las del centro, como en las Notas de Voz,
/// y hacen una onda suave mientras se escribe el texto.
public final class BarrasVoz {
    public let cuantas: Int
    /// Alto de cada barra, de 0, un punto, a 1, toda la cápsula.
    public private(set) var alturas: [Double]
    private let campana: [Double]
    private let semillas: [Double]
    private var tiempo = 0.0
    private var ultima: Date?

    public init(cuantas: Int) {
        self.cuantas = max(1, cuantas)
        let n = Double(self.cuantas)
        alturas = Array(repeating: 0, count: self.cuantas)
        campana = (0..<self.cuantas).map { 0.45 + 0.55 * sin(Double.pi * (Double($0) + 0.5) / n) }
        semillas = (0..<self.cuantas).map { Double($0) * 2.39 }
    }

    public func avanzar(a fecha: Date, nivel: Double, escuchando: Bool) {
        let paso = ultima.map { min(max(fecha.timeIntervalSince($0), 0), GiroBola.pasoMaximo) } ?? 0
        ultima = fecha
        tiempo += paso
        let voz = min(1, max(0, nivel))
        for i in alturas.indices {
            let objetivo: Double
            if escuchando {
                let vida = 0.65 + 0.35 * sin(tiempo * 9 + semillas[i] * 3)
                objetivo = voz * campana[i] * vida
            } else {
                objetivo = 0.2 * max(0, sin(tiempo * 7 - Double(i) * 0.7))
            }
            let rapidez = objetivo > alturas[i] ? 22.0 : 9.0
            alturas[i] += (objetivo - alturas[i]) * min(1, paso * rapidez)
        }
    }
}

/// Una voz de prueba para la vista previa de los ajustes: sílabas de 0,15 a 0,3 s con fuerza distinta y alguna pausa.
public final class VozSimulada {
    private var semilla: UInt64
    private var t = 0.0
    private var duracion = 0.2
    private var fuerza = 0.0

    public init(semilla: UInt64 = 0x9E37_79B9_7F4A_7C15) {
        self.semilla = semilla
    }

    /// El volumen tras `paso` segundos más de voz, de 0 a 1.
    public func nivel(tras paso: Double) -> Double {
        t += max(0, paso)
        if t >= duracion {
            t = 0
            duracion = 0.15 + azar() * 0.15
            fuerza = azar() < 0.15 ? 0.05 : 0.45 + azar() * 0.55
        }
        return min(1, fuerza * pow(sin(Double.pi * t / duracion), 0.7))
    }

    private func azar() -> Double {
        semilla = semilla &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(semilla >> 11) / Double(UInt64(1) << 53)
    }
}
