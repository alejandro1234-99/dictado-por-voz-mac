import DictadoNucleo
import Foundation
import Testing

@Suite("Lo que se elige de la bola")
struct AparienciaBolaTests {
    @Test("Hay 31 estilos en 6 familias, sin nombres repetidos dentro de cada una")
    func catalogo() {
        #expect(EstiloBola.allCases.count == 31)
        for familia in EstiloBola.Familia.allCases {
            let nombres = EstiloBola.de(familia).map(\.nombre)
            #expect(!nombres.isEmpty)
            #expect(Set(nombres).count == nombres.count)
        }
        #expect(EstiloBola.de(.metales).count == 11)
        #expect(EstiloBola.de(.piedras).count == 6)
    }

    @Test("Los valores se recortan a lo que se puede elegir")
    func recorte() {
        let apariencia = AparienciaBola(tamano: 500, halo: -1, brillo: 9)
        #expect(apariencia.tamano == AparienciaBola.tamanos.upperBound)
        #expect(apariencia.halo == 0)
        #expect(apariencia.brillo == AparienciaBola.brillos.upperBound)
    }

    @Test("Se guarda y se recupera igual")
    func guardar() throws {
        let apariencia = AparienciaBola(estilo: .oroRosa, tamano: 88, halo: 0.7, brillo: 1.1, posicion: .arriba)
        let datos = try JSONEncoder().encode(apariencia)
        #expect(try JSONDecoder().decode(AparienciaBola.self, from: datos) == apariencia)
    }

    @Test("Lo que falta o no se entiende queda como viene de serie")
    func guardadoAntiguo() throws {
        let datos = Data(#"{"estilo":"unobsoleto","tamano":72}"#.utf8)
        let apariencia = try JSONDecoder().decode(AparienciaBola.self, from: datos)
        #expect(apariencia.estilo == AparienciaBola.estandar.estilo)
        #expect(apariencia.tamano == 72)
        #expect(apariencia.posicion == .abajo)
    }
}

@Suite("Pintar la bola")
struct PintorBolaTests {
    private let lado = 48
    private var bolas: [EstiloBola] { EstiloBola.allCases.filter { !$0.esCapsula } }

    private func pixel(_ pintor: PintorBola, _ i: Int, _ j: Int) -> (r: Int, g: Int, b: Int, a: Int) {
        let o = (j * pintor.lado + i) * 4
        let p = pintor.pixeles
        return (Int(p[o]), Int(p[o + 1]), Int(p[o + 2]), Int(p[o + 3]))
    }

    /// Color medio de la bola, sin la opacidad multiplicada.
    private func colorMedio(_ pintor: PintorBola) -> (r: Double, g: Double, b: Double) {
        var r = 0.0, g = 0.0, b = 0.0, peso = 0.0
        let p = pintor.pixeles
        for o in stride(from: 0, to: p.count, by: 4) where p[o + 3] > 200 {
            let a = Double(p[o + 3])
            r += Double(p[o]) / a
            g += Double(p[o + 1]) / a
            b += Double(p[o + 2]) / a
            peso += 1
        }
        return (r / peso, g / peso, b / peso)
    }

    @Test("Todas las bolas pintan dentro del círculo y dejan las esquinas transparentes")
    func circulo() {
        let pintor = PintorBola(lado: lado)
        for estilo in bolas {
            pintor.pintar(estilo: estilo, fase: 1, energia: 0.5)
            #expect(pixel(pintor, 0, 0).a == 0, "\(estilo)")
            #expect(pixel(pintor, lado / 2, lado / 2).a > 0, "\(estilo)")
            #expect(pixel(pintor, lado / 2, 2).a > 0, "\(estilo)")
        }
    }

    @Test("La bola se mueve: otro giro da otra imagen")
    func movimiento() {
        let pintor = PintorBola(lado: lado)
        for estilo in bolas {
            pintor.pintar(estilo: estilo, fase: 0, energia: 0.5)
            let antes = pintor.pixeles
            pintor.pintar(estilo: estilo, fase: 2, energia: 0.5)
            #expect(pintor.pixeles != antes, "\(estilo)")
        }
    }

    @Test("El cristal deja ver lo de detrás; la perla, no")
    func transparencia() {
        let pintor = PintorBola(lado: lado)
        pintor.pintar(estilo: .cristal, fase: 0, energia: 0)
        let cristal = pixel(pintor, lado / 2 + 8, lado / 2 + 8).a
        pintor.pintar(estilo: .perla, fase: 0, energia: 0)
        let perla = pixel(pintor, lado / 2 + 8, lado / 2 + 8).a
        #expect(cristal < 200)
        #expect(perla == 255)
    }

    @Test("Más brillo, más claro")
    func brillo() {
        let pintor = PintorBola(lado: lado)
        pintor.pintar(estilo: .perla, fase: 0, energia: 0, brillo: 0.8)
        let oscuro = colorMedio(pintor)
        pintor.pintar(estilo: .perla, fase: 0, energia: 0, brillo: 1.2)
        let claro = colorMedio(pintor)
        #expect(claro.r + claro.g + claro.b > oscuro.r + oscuro.g + oscuro.b)
    }

    @Test("Cada metal tiene su color: el oro tira a amarillo, el cobre a rojizo y la plata es neutra")
    func metales() {
        let pintor = PintorBola(lado: lado)
        pintor.pintar(estilo: .oro, fase: 0, energia: 0)
        let oro = colorMedio(pintor)
        pintor.pintar(estilo: .cobre, fase: 0, energia: 0)
        let cobre = colorMedio(pintor)
        pintor.pintar(estilo: .plata, fase: 0, energia: 0)
        let plata = colorMedio(pintor)
        #expect(oro.r > oro.b * 1.6 && oro.g > oro.b * 1.2)
        #expect(cobre.r > cobre.g && cobre.g > cobre.b)
        #expect(abs(plata.r - plata.b) < 0.08)
    }

    @Test("Las cápsulas no se pintan aquí")
    func capsulas() {
        let pintor = PintorBola(lado: lado)
        pintor.pintar(estilo: .capsulaGrafito, fase: 0, energia: 1)
        #expect(pintor.pixeles.allSatisfy { $0 == 0 })
    }

    @Test("Al tamaño máximo, un fotograma de cualquier estilo tarda menos de 8 ms")
    func rapidez() {
        // 120 puntos a 1,5 píxeles por punto, como en la app.
        let pintor = PintorBola(lado: 180)
        var peor = 0.0
        for estilo in bolas {
            let inicio = Date()
            for fotograma in 0..<10 {
                pintor.pintar(estilo: estilo, fase: Double(fotograma) * 0.1, energia: 0.8)
            }
            peor = max(peor, Date().timeIntervalSince(inicio) / 10)
        }
        print("Peor fotograma: \(String(format: "%.2f", peor * 1000)) ms")
        #if !DEBUG
        #expect(peor < 0.008)
        #endif
    }
}

@Suite("Barras y voz de prueba")
struct BarrasVozTests {
    @Test("En silencio las barras se quedan en un punto; con voz, las del centro suben más")
    func barras() {
        let barras = BarrasVoz(cuantas: 9)
        let inicio = Date()
        for f in 0...60 {
            barras.avanzar(a: inicio.addingTimeInterval(Double(f) / 60), nivel: 0, escuchando: true)
        }
        #expect(barras.alturas.allSatisfy { $0 < 0.01 })
        for f in 61...120 {
            barras.avanzar(a: inicio.addingTimeInterval(Double(f) / 60), nivel: 1, escuchando: true)
        }
        #expect(barras.alturas[4] > barras.alturas[0])
        #expect(barras.alturas[4] > 0.3)
    }

    @Test("Mientras se escribe, una onda baja")
    func onda() {
        let barras = BarrasVoz(cuantas: 9)
        let inicio = Date()
        for f in 0...120 {
            barras.avanzar(a: inicio.addingTimeInterval(Double(f) / 60), nivel: 1, escuchando: false)
        }
        #expect(barras.alturas.allSatisfy { $0 <= 0.2 })
        #expect(barras.alturas.contains { $0 > 0.02 })
    }

    @Test("La voz de prueba va de 0 a 1 y suena de verdad")
    func voz() {
        let voz = VozSimulada()
        let niveles = (0..<240).map { _ in voz.nivel(tras: 1.0 / 60) }
        #expect(niveles.allSatisfy { $0 >= 0 && $0 <= 1 })
        #expect(niveles.contains { $0 > 0.4 })
    }
}
