import DictadoNucleo
import Foundation
import Testing

@Suite("Volumen de la voz")
struct VolumenTests {
    @Test("Un tono constante tiene su propio valor como volumen")
    func rmsConstante() {
        let muestras: [Float] = Array(repeating: 0.5, count: 512)
        let rms = muestras.withUnsafeBufferPointer { Volumen.rms($0) }
        #expect(abs(rms - 0.5) < 0.0001)
    }

    @Test("Sin muestras no hay volumen")
    func rmsVacio() {
        let rms = [Float]().withUnsafeBufferPointer { Volumen.rms($0) }
        #expect(rms == 0)
    }

    @Test("El silencio y el ruido de fondo dan 0; la voz fuerte, 1")
    func escala() {
        #expect(Volumen.nivel(rms: 0) == 0)
        #expect(Volumen.nivel(rms: 0.001) == 0)  // -60 dB
        #expect(Volumen.nivel(rms: 1) == 1)  // 0 dB
        let medio = Volumen.nivel(rms: 0.03)  // unos -30 dB, voz normal
        #expect(medio > 0.4 && medio < 0.7)
    }
}

@Suite("Giro de la bola")
struct GiroBolaTests {
    @Test("Con voz, la bola gira más deprisa que en calma")
    func aceleraConVoz() {
        let calma = GiroBola()
        let voz = GiroBola()
        let inicio = Date()
        for fotograma in 0...60 {
            let fecha = inicio.addingTimeInterval(Double(fotograma) / 60)
            calma.avanzar(a: fecha, nivel: 0)
            voz.avanzar(a: fecha, nivel: 1)
        }
        #expect(abs(calma.fase - GiroBola.velocidadCalma) < 0.01)
        #expect(voz.fase > calma.fase * 4)
        #expect(voz.energia > 0.99)
    }

    @Test("La energía sube deprisa y baja despacio")
    func subeDeprisaBajaDespacio() {
        let giro = GiroBola()
        let inicio = Date()
        giro.avanzar(a: inicio, nivel: 1)
        giro.avanzar(a: inicio.addingTimeInterval(0.05), nivel: 1)
        let tras50msHablando = giro.energia
        giro.avanzar(a: inicio.addingTimeInterval(0.10), nivel: 0)
        let bajada = tras50msHablando - giro.energia
        #expect(tras50msHablando > 0.8)
        #expect(bajada < tras50msHablando * 0.25)
    }

    @Test("Un parón largo no hace saltar la bola")
    func paronLargo() {
        let giro = GiroBola()
        let inicio = Date()
        giro.avanzar(a: inicio, nivel: 0)
        giro.avanzar(a: inicio.addingTimeInterval(30), nivel: 0)
        #expect(giro.fase <= GiroBola.pasoMaximo * GiroBola.velocidadCalma + 0.0001)
    }

    @Test("Un nivel fuera de 0 a 1 se recorta")
    func nivelRecortado() {
        let giro = GiroBola()
        let inicio = Date()
        giro.avanzar(a: inicio, nivel: 0)
        giro.avanzar(a: inicio.addingTimeInterval(0.1), nivel: 5)
        #expect(giro.energia <= 1)
    }
}
