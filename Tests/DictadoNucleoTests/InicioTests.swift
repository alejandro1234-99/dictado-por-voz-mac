import DictadoNucleo
import Foundation
import Testing

@Suite("Métricas de Inicio")
struct MetricasTests {
    /// Madrid, con la semana empezando en lunes.
    private var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        c.firstWeekday = 2
        return c
    }

    /// Miércoles 28 de octubre de 2026 a las 18:00 en Madrid.
    private var ahora: Date {
        calendario.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 18))!
    }

    private func registro(diasAtras: Int, hora: Int = 12, palabras: Int, segundos: Double) -> RegistroDictado {
        let dia = calendario.date(byAdding: .day, value: -diasAtras, to: calendario.startOfDay(for: ahora))!
        return RegistroDictado(fecha: dia.addingTimeInterval(Double(hora) * 3600), palabras: palabras, segundosAudio: segundos)
    }

    private var historial: [RegistroDictado] {
        [
            registro(diasAtras: 0, palabras: 120, segundos: 50),
            registro(diasAtras: 0, hora: 16, palabras: 30, segundos: 10),
            registro(diasAtras: 1, palabras: 200, segundos: 80),
            registro(diasAtras: 2, palabras: 100, segundos: 40),
            // El domingo pasado: fuera de la semana, que empezó el lunes 26.
            registro(diasAtras: 3, palabras: 50, segundos: 20),
            // Hace 10 días: corta la racha y queda fuera del gráfico.
            registro(diasAtras: 10, palabras: 500, segundos: 200),
            // Sin voz: no cuenta.
            registro(diasAtras: 0, palabras: 0, segundos: 2),
        ]
    }

    @Test("Hoy, semana y total")
    func cuentas() {
        let m = Metricas.calcular(historial, hoy: ahora, calendario: calendario)
        #expect(m.hoy == 150)
        #expect(m.dictadosHoy == 2)
        #expect(m.semana == 450)
        #expect(m.total == 1000)
    }

    @Test("Palabras por minuto con el audio grabado")
    func velocidad() {
        let m = Metricas.calcular(historial, hoy: ahora, calendario: calendario)
        // 1.000 palabras en 400 s de voz: 150 por minuto.
        #expect(m.palabrasPorMinuto == 150)
    }

    @Test("Tiempo ahorrado frente a escribir a 40 palabras por minuto")
    func ahorro() {
        let m = Metricas.calcular(historial, hoy: ahora, calendario: calendario)
        // A mano, 1.000 palabras son 25 min; hablando se tardaron 400 s. El toque sin voz no cuenta.
        #expect(m.segundosAhorrados == 1500 - 400)
        #expect(Metricas.tiempo(m.segundosAhorrados) == "18 min")
    }

    @Test("Días seguidos: hoy, ayer, anteayer y el domingo; el hueco anterior corta")
    func racha() {
        #expect(Metricas.calcular(historial, hoy: ahora, calendario: calendario).diasSeguidos == 4)
        // Si hoy aún no se ha dictado, la racha sigue viva desde ayer.
        let sinHoy = historial.filter { !calendario.isDate($0.fecha, inSameDayAs: ahora) }
        #expect(Metricas.calcular(sinHoy, hoy: ahora, calendario: calendario).diasSeguidos == 3)
        #expect(Metricas.calcular([], hoy: ahora, calendario: calendario).diasSeguidos == 0)
    }

    @Test("El gráfico tiene los 7 últimos días, de más antiguo a hoy")
    func grafico() {
        let dias = Metricas.calcular(historial, hoy: ahora, calendario: calendario).ultimos7Dias
        #expect(dias.map(\.palabras) == [0, 0, 0, 50, 100, 200, 150])
        #expect(calendario.isDate(dias.last!.dia, inSameDayAs: ahora))
    }

    @Test("Cifras con punto de miles y tiempos legibles")
    func formato() {
        #expect(Metricas.cifra(7) == "7")
        #expect(Metricas.cifra(1284) == "1.284")
        #expect(Metricas.cifra(52417) == "52.417")
        #expect(Metricas.cifra(1_234_567) == "1.234.567")
        #expect(Metricas.tiempo(15_000) == "4 h 10 min")
        #expect(Metricas.tiempo(7200) == "2 h")
        #expect(Metricas.tiempo(40) == "40 s")
    }
}

@Suite("Diccionario")
struct DiccionarioTests {
    private let entradas = [
        EntradaDiccionario(palabra: "Claude Code", seOye: "cloud code"),
        EntradaDiccionario(palabra: "GitHub", seOye: "guit hab"),
        EntradaDiccionario(palabra: "Postgres", seOye: "post gres"),
        EntradaDiccionario(palabra: "R2D2", seOye: "erre dos de dos"),
        EntradaDiccionario(palabra: "GitHub"),
        EntradaDiccionario(palabra: "Kubernetes"),
        EntradaDiccionario(palabra: "VS Code"),
    ]

    @Test(
        "Las correcciones cambian lo que se oyó por cómo se escribe",
        arguments: [
            ("abre cloud code", "abre Claude Code"),
            ("Abre Cloud Code ya", "Abre Claude Code ya"),
            ("cloud  code y guit hab", "Claude Code y GitHub"),
            ("la base post gres", "la base Postgres"),
            ("llega erre dos de dos", "llega R2D2"),
            ("trabajo en kubernetes", "trabajo en Kubernetes"),
            ("abre vs code", "abre VS Code"),
            ("github va bien", "GitHub va bien"),
            ("cloud coder no es lo mismo", "cloud coder no es lo mismo"),
            ("la nube cloud sola", "la nube cloud sola"),
            ("kubernetesa no es una palabra propia", "kubernetesa no es una palabra propia"),
            ("¿cloud code?", "¿Claude Code?"),
        ]
    )
    func correcciones(entrada: String, esperado: String) {
        #expect(Diccionario.aplicar(entradas, a: entrada) == esperado)
    }

    @Test("Al motor de voz se le pasa cada palabra una vez, como se escribe")
    func motor() {
        #expect(Diccionario.palabrasParaElMotor(entradas) == ["Claude Code", "GitHub", "Postgres", "R2D2", "Kubernetes", "VS Code"])
    }

    @Test("Un diccionario vacío no toca el texto")
    func vacio() {
        #expect(Diccionario.aplicar([], a: "hola cloud code") == "hola cloud code")
    }
}
