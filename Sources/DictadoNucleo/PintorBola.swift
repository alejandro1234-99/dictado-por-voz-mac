import Foundation

/// Pinta la bola punto a punto, en el procesador.
///
/// Sin Metal: con las Command Line Tools no se pueden compilar sombreadores. A 120 puntos son unos 15.000 píxeles por
/// fotograma, que el procesador pinta de sobra. Las fórmulas son las de la muestra web,
/// con los metales y las piedras añadidos. La geometría de la esfera se calcula una vez por tamaño.
public final class PintorBola {
    public let lado: Int
    /// RGBA con la opacidad ya multiplicada, fila a fila desde arriba: listo para un CGImage.
    public private(set) var pixeles: [UInt8]

    private let geometria: [Punto]

    /// Lo que no cambia de un fotograma a otro en cada píxel de la esfera.
    private struct Punto {
        var x = 0.0, y = 0.0, z = 0.0
        /// Cuánto mira hacia el borde: 0 en el centro, 1 en el canto.
        var fres = 0.0
        /// Luz difusa y brillo con la luz principal, arriba a la izquierda.
        var lam = 0.0, nh = 0.0
        /// Dirección en la que refleja y lo que ve del estudio en esa dirección.
        var rx = 0.0, ry = 0.0, rz = 0.0, estudio = 0.0
        /// Opacidad del canto, para que el borde no salga dentado.
        var filo = 0.0
        var dentro = false
    }

    private struct Color {
        var r: Double, g: Double, b: Double, a: Double = 1
    }

    private static let luz = normalizar(-0.45, -0.62, 0.64)
    private static let medio = normalizar(luz.0, luz.1, luz.2 + 1)
    private static let luzSuave = normalizar(-0.42, -0.62, 0.66)
    private static let medioSuave = normalizar(luzSuave.0, luzSuave.1, luzSuave.2 + 1)

    public init(lado: Int) {
        let n = max(4, lado)
        self.lado = n
        pixeles = [UInt8](repeating: 0, count: n * n * 4)
        var puntos = [Punto](repeating: Punto(), count: n * n)
        for j in 0..<n {
            let y = (Double(j) + 0.5) / Double(n) * 2 - 1
            for i in 0..<n {
                let x = (Double(i) + 0.5) / Double(n) * 2 - 1
                let r2 = x * x + y * y
                guard r2 < 1 else { continue }
                let z = (1 - r2).squareRoot()
                var p = Punto()
                p.x = x
                p.y = y
                p.z = z
                p.dentro = true
                p.fres = pow(1 - z, 3)
                p.lam = max(0, x * Self.luz.0 + y * Self.luz.1 + z * Self.luz.2)
                p.nh = max(0, x * Self.medio.0 + y * Self.medio.1 + z * Self.medio.2)
                p.rx = 2 * z * x
                p.ry = 2 * z * y
                p.rz = 2 * z * z - 1
                p.estudio = Self.estudio(p.rx, p.ry, p.rz)
                p.filo = min(1, (1 - r2.squareRoot()) * Double(n) * 0.5)
                puntos[j * n + i] = p
            }
        }
        geometria = puntos
    }

    /// Pinta un fotograma. `fase` es el giro acumulado y `energia` la voz, de 0 a 1. Las cápsulas no se pintan aquí.
    public func pintar(estilo: EstiloBola, fase: Double, energia: Double, brillo: Double = 1) {
        let e = min(max(energia, 0), 1)
        let giro = Giro(fase: fase, energia: e)
        for k in 0..<geometria.count {
            let o = k * 4
            let p = geometria[k]
            guard p.dentro, !estilo.esCapsula else {
                pixeles[o] = 0
                pixeles[o + 1] = 0
                pixeles[o + 2] = 0
                pixeles[o + 3] = 0
                continue
            }
            let c = color(estilo, p, giro)
            let a = c.a * p.filo
            pixeles[o] = Self.byte(c.r * brillo * a)
            pixeles[o + 1] = Self.byte(c.g * brillo * a)
            pixeles[o + 2] = Self.byte(c.b * brillo * a)
            pixeles[o + 3] = Self.byte(255 * a)
        }
    }

    /// Lo que cambia en cada fotograma, calculado una vez.
    private struct Giro {
        let fase: Double, energia: Double
        let coseno: Double, seno: Double

        init(fase: Double, energia: Double) {
            self.fase = fase
            self.energia = energia
            coseno = cos(fase * 0.35)
            seno = sin(fase * 0.35)
        }
    }

    private func color(_ estilo: EstiloBola, _ p: Punto, _ g: Giro) -> Color {
        switch estilo {
        case .perla: return perla(p, g)
        case .cristal: return vidrio(p, g, tinte: (0.59, 0.75, 1.0), densidad: 0)
        case .mercurio: return mercurio(p, g)
        case .grafito: return grafito(p, g)
        case .nacar: return nacar(p, g)
        case .hielo: return hielo(p, g)
        // Colores de los metales: base de datos Physically Based (physicallybased.info, CC0), en lineal y usados tal
        // cual como tinte. El bronce y el oro rosa no están en ella: van a ojo.
        case .oro: return metal(p, g, tinte: (1.0, 0.773, 0.307), aspereza: 0.08)
        case .oroRosa: return metal(p, g, tinte: (0.97, 0.74, 0.66), aspereza: 0.10)
        case .plata: return metal(p, g, tinte: (0.991, 0.985, 0.974), aspereza: 0.05)
        case .platino: return metal(p, g, tinte: (0.765, 0.73, 0.676), aspereza: 0.12)
        case .bronce: return metal(p, g, tinte: (0.80, 0.55, 0.30), aspereza: 0.20)
        case .cobre: return metal(p, g, tinte: (0.932, 0.623, 0.522), aspereza: 0.12)
        case .laton: return metal(p, g, tinte: (0.91, 0.778, 0.423), aspereza: 0.10)
        case .titanio: return metal(p, g, tinte: (0.441, 0.4, 0.361), aspereza: 0.38)
        case .acero: return metal(p, g, tinte: (0.669, 0.639, 0.598), aspereza: 0.26)
        case .cromo: return metal(p, g, tinte: (0.654, 0.685, 0.701), aspereza: 0.02)
        case .aluminio: return metal(p, g, tinte: (0.916, 0.923, 0.924), aspereza: 0.30)
        case .marmol: return marmol(p, g)
        case .obsidiana: return obsidiana(p, g)
        case .jade: return jade(p, g)
        case .zafiro: return vidrio(p, g, tinte: (0.12, 0.30, 0.95), densidad: 1)
        case .esmeralda: return vidrio(p, g, tinte: (0.06, 0.68, 0.40), densidad: 1)
        case .rubi: return vidrio(p, g, tinte: (0.88, 0.06, 0.20), densidad: 1)
        case .suaveAzul: return suave(p, g, a: (202, 220, 252), b: (160, 185, 209), borde: (104, 128, 162))
        case .suavePlata: return suave(p, g, a: (236, 238, 242), b: (182, 188, 198), borde: (112, 118, 128))
        case .seda: return seda(p, g)
        case .nube: return nube(p, g)
        case .aurora: return aurora(p, g)
        case .capsulaCristal, .capsulaGrafito, .capsulaCompacta: return Color(r: 0, g: 0, b: 0, a: 0)
        }
    }

    // MARK: - En 3D

    private func perla(_ p: Punto, _ g: Giro) -> Color {
        let (v, w) = corriente(p, g)
        let m = Self.suave(0, 1, v)
        let veta = 0.75 * Self.suave(0.45, 1, w)
        var c = Color(
            r: Self.mezcla(Self.mezcla(208, 156, m), 255, veta),
            g: Self.mezcla(Self.mezcla(224, 182, m), 255, veta),
            b: Self.mezcla(Self.mezcla(252, 214, m), 255, veta)
        )
        c = Self.multiplicar(c, (0.62 + 0.38 * p.lam) * sombraAbajo(p))
        let reflejo = 255 * (0.10 * p.estudio + 0.35 * p.fres * p.estudio) + 255 * 0.28 * pow(p.nh, 18)
        return Self.sumar(c, reflejo)
    }

    /// Vidrio con un núcleo de luz. Sin densidad es transparente; con densidad, una gema de color.
    private func vidrio(_ p: Punto, _ g: Giro, tinte: (Double, Double, Double), densidad: Double) -> Color {
        // El núcleo se ve a través del vidrio algo agrandado hacia el centro, como con una lupa.
        let lente = 0.62 * (1 - 0.25 * (1 - p.z))
        let ix = p.x / lente, iy = p.y / lente
        let d2 = ix * ix + iy * iy
        var nucleo = 0.0
        var veta = 0.0
        if d2 < 1 {
            let interior = Punto(x: ix, y: iy, z: (1 - d2).squareRoot())
            let (v, w) = corriente(interior, g, escalaTiempo: 1.2)
            nucleo = exp(-d2 / 0.45) * (0.55 + 0.45 * g.energia) * (0.6 + 0.4 * v)
            veta = w
        }
        let cuerpo = 0.10 + 0.78 * p.fres + densidad * (0.30 + 0.25 * (1 - p.fres))
        let claro = 0.6 * veta
        let nr = Self.mezcla(255 * tinte.0, 255, claro)
        let ng = Self.mezcla(255 * tinte.1, 255, claro)
        let nb = Self.mezcla(255 * tinte.2, 255, claro)
        // El vidrio toma el color del estudio; las gemas, además, el suyo, más oscuro hacia dentro.
        let profundidad = densidad * (0.55 + 0.45 * p.fres)
        let vr = Self.mezcla(228 * p.estudio, 255 * tinte.0 * (0.35 + 0.65 * p.estudio), profundidad)
        let vg = Self.mezcla(236 * p.estudio, 255 * tinte.1 * (0.35 + 0.65 * p.estudio), profundidad)
        let vb = Self.mezcla(255 * p.estudio, 255 * tinte.2 * (0.35 + 0.65 * p.estudio), profundidad)

        var a = nucleo + cuerpo * (1 - nucleo)
        let resto = cuerpo * (1 - nucleo)
        let divisor = max(a, 0.001)
        var c = Color(
            r: (nr * nucleo + vr * resto) / divisor,
            g: (ng * nucleo + vg * resto) / divisor,
            b: (nb * nucleo + vb * resto) / divisor
        )
        let destello = pow(p.nh, 90) + 0.6 * exp(-(pow(p.rx + 0.42, 2) / 0.02 + pow(p.ry + 0.52, 2) / 0.01))
        a = min(1, a + destello)
        c = Self.sumar(c, 255 * destello)
        c.a = min(1, a)
        return c
    }

    private func mercurio(_ p: Punto, _ g: Giro) -> Color {
        let (v, w) = corriente(p, g)
        let d = 0.25 + 0.45 * g.energia
        let visto = Self.estudio(p.rx + d * (v - 0.5), p.ry + d * (w - 0.5), p.rz)
        let luz = min(1.4, 0.34 + 0.95 * visto) * sombraAbajo(p)
        let destello = 255 * pow(p.nh, 120) * 0.9
        return Color(r: 232 * luz + destello, g: 236 * luz + destello, b: 244 * luz + destello)
    }

    private func grafito(_ p: Punto, _ g: Giro) -> Color {
        let (v, w) = corriente(p, g)
        let m = Self.suave(0, 1, v)
        let veta = 0.6 * Self.suave(0.55, 1, w)
        var c = Color(
            r: Self.mezcla(Self.mezcla(26, 40, m), 92, veta),
            g: Self.mezcla(Self.mezcla(30, 50, m), 118, veta),
            b: Self.mezcla(Self.mezcla(38, 66, m), 152, veta)
        )
        c = Self.multiplicar(c, (0.7 + 0.3 * p.lam) * sombraAbajo(p))
        let reflejo = p.estudio * (0.06 + 0.6 * p.fres)
        c.r += 215 * reflejo
        c.g += 228 * reflejo
        c.b += 255 * reflejo
        return Self.sumar(c, 255 * (0.85 * pow(p.nh, 70) + 0.5 * focoReflejado(p, 0.025, 0.012)))
    }

    private func nacar(_ p: Punto, _ g: Giro) -> Color {
        let (v, w) = corriente(p, g)
        let m = Self.suave(0, 1, v)
        var c = Color(r: Self.mezcla(246, 222, m), g: Self.mezcla(244, 225, m), b: Self.mezcla(248, 234, m))
        c = Self.multiplicar(c, (0.74 + 0.26 * p.lam) * sombraAbajo(p))
        // Tornasol: el tono cambia con el ángulo de la superficie, muy suave.
        let fase = 1.3 * p.fres + 0.35 * w + 0.04 * g.fase
        let fuerza = 255 * 0.11 * (0.3 + 0.7 * p.fres + 0.4 * g.energia)
        c.r += fuerza * cos(6.283 * fase)
        c.g += fuerza * cos(6.283 * (fase + 0.33))
        c.b += fuerza * cos(6.283 * (fase + 0.67))
        let reflejo = 255 * (0.08 * p.estudio + 0.3 * p.fres * p.estudio) + 255 * 0.3 * pow(p.nh, 16)
        return Self.sumar(c, reflejo)
    }

    private func hielo(_ p: Punto, _ g: Giro) -> Color {
        let (v, w) = corriente(p, g, escalaGiro: 0.7)
        let m = Self.suave(0, 1, v) * 0.6
        var c = Color(r: Self.mezcla(232, 200, m), g: Self.mezcla(241, 220, m), b: Self.mezcla(251, 242, m))
        c = Self.multiplicar(c, (0.78 + 0.22 * p.lam) * sombraAbajo(p))
        let interior = exp(-(p.x * p.x + p.y * p.y) / 0.32) * (0.18 + 0.82 * g.energia) * (0.75 + 0.25 * w)
        c.r = Self.mezcla(c.r, 255, interior)
        c.g = Self.mezcla(c.g, 255, interior)
        c.b = Self.mezcla(c.b, 255, interior * 0.9)
        let halo = 0.25 * interior * (1 - interior)
        c.r = Self.mezcla(c.r, 170, halo)
        c.g = Self.mezcla(c.g, 205, halo)
        c = Self.sumar(c, 255 * (0.06 * p.estudio + 0.28 * p.fres * p.estudio) + 255 * 0.22 * pow(p.nh, 8))
        c.a = min(1, 0.72 + 0.28 * p.fres + 0.3 * interior)
        return c
    }

    // MARK: - Metales

    /// Un metal pulido solo refleja: lo que se ve es el estudio teñido de su color. En el canto refleja casi blanco.
    /// El estudio gira alrededor de la bola con la voz, así que los reflejos barren la superficie como si girara.
    private func metal(_ p: Punto, _ g: Giro, tinte: (Double, Double, Double), aspereza: Double) -> Color {
        var rx = p.rx * g.coseno + p.rz * g.seno
        let rz = -p.rx * g.seno + p.rz * g.coseno
        var ry = p.ry
        let (v, w) = corriente(p, g)
        let onda = 0.04 + 0.16 * g.energia
        rx += onda * (v - 0.5)
        ry += onda * (w - 0.5)
        let visto = Self.estudioMetal(rx, ry, rz, aspereza: aspereza) * sombraAbajo(p)
        let canto = pow(1 - p.z, 5)
        let fr = tinte.0 + (1 - tinte.0) * canto
        let fg = tinte.1 + (1 - tinte.1) * canto
        let fb = tinte.2 + (1 - tinte.2) * canto
        let exponente = Self.mezcla(160, 22, aspereza)
        let destello = 255 * pow(p.nh, exponente) * Self.mezcla(0.9, 0.3, aspereza)
        return Color(
            r: 255 * fr * visto + destello * fr,
            g: 255 * fg * visto + destello * fg,
            b: 255 * fb * visto + destello * fb
        )
    }

    // MARK: - Piedras

    private func marmol(_ p: Punto, _ g: Giro) -> Color {
        // La piedra gira con la bola; las vetas están quietas en ella, como en una piedra de verdad.
        let px = p.x * g.coseno + p.z * g.seno
        let pz = -p.x * g.seno + p.z * g.coseno
        // Ruido de varias capas, el de la piedra en los programas de 3D: vetas en diagonal, rotas por la turbulencia.
        let turbulencia = Self.capas(2.6 * px + 4.1, 2.6 * p.y, 2.6 * pz)
        let detalle = Self.capas(6.0 * px, 6.0 * p.y + 7.3, 6.0 * pz)
        let veta = sin(3.4 * (px + 0.55 * p.y) + 7.0 * turbulencia)
        let gruesa = pow(1 - abs(veta), 7) * (0.35 + 0.65 * detalle)
        let fina = 0.45 * pow(1 - abs(sin(8.0 * (p.y - 0.35 * pz) + 9.0 * detalle)), 22)
        let fondo = Self.mezcla(248, 230, Self.suave(0.3, 0.8, turbulencia))
        var c = Color(r: fondo, g: fondo, b: fondo - 1)
        let oscuro = min(0.7, 0.62 * gruesa + fina)
        c.r = Self.mezcla(c.r, 128, oscuro)
        c.g = Self.mezcla(c.g, 130, oscuro)
        c.b = Self.mezcla(c.b, 138, oscuro)
        c = Self.multiplicar(c, (0.68 + 0.32 * p.lam) * sombraAbajo(p))
        let reflejo = 255 * (0.06 * p.estudio + 0.3 * p.fres * p.estudio) + 255 * 0.45 * pow(p.nh, 60)
        return Self.sumar(c, reflejo)
    }

    private func obsidiana(_ p: Punto, _ g: Giro) -> Color {
        let (v, _) = corriente(p, g)
        let brillo = 6 * Self.suave(0.6, 1, v)
        var c = Color(r: 10 + brillo, g: 10 + brillo, b: 14 + brillo * 1.3)
        let reflejo = p.estudio * (0.05 + 0.7 * p.fres)
        c.r += 220 * reflejo
        c.g += 225 * reflejo
        c.b += 235 * reflejo
        return Self.sumar(c, 255 * (0.95 * pow(p.nh, 90) + 0.6 * focoReflejado(p, 0.02, 0.01)))
    }

    private func jade(_ p: Punto, _ g: Giro) -> Color {
        let (v, w) = corriente(p, g, escalaGiro: 0.8)
        let m = Self.suave(0, 1, v)
        let nube = 0.5 * Self.suave(0.5, 1, w)
        var c = Color(
            r: Self.mezcla(Self.mezcla(58, 120, m), 176, nube),
            g: Self.mezcla(Self.mezcla(132, 186, m), 222, nube),
            b: Self.mezcla(Self.mezcla(96, 150, m), 190, nube)
        )
        // Algo de luz entra en la piedra y sale por el lado en sombra.
        let interior = 0.18 * (1 - p.lam) * p.z
        c = Self.multiplicar(c, (0.66 + 0.34 * p.lam) * sombraAbajo(p))
        c.r += 40 * interior
        c.g += 120 * interior
        c.b += 70 * interior
        let reflejo = 255 * (0.05 * p.estudio + 0.25 * p.fres * p.estudio) + 255 * 0.4 * pow(p.nh, 40)
        return Self.sumar(c, reflejo)
    }

    // MARK: - Suaves

    private func suave(
        _ p: Punto, _ g: Giro, a: (Double, Double, Double), b: (Double, Double, Double), borde: (Double, Double, Double)
    ) -> Color {
        let giro = 0.32 + 0.28 * g.energia
        let f = g.fase
        let qx = p.x + giro * sin(1.7 * p.y + 0.9 * f + p.z)
        let qy = p.y + giro * cos(1.3 * p.x - 0.7 * f)
        let v = 0.5 + 0.5 * sin(2.2 * qx + 1.6 * qy + 1.1 * f + 1.5 * sin(1.4 * qx - 0.6 * f))
        let w = 0.5 + 0.5 * sin(1.8 * qy - 2.1 * qx - 0.8 * f + 1.2 * cos(1.1 * qy + 0.5 * f))
        let mv = Self.suave(0, 1, v)
        let mw = 0.8 * Self.suave(0.42, 1, w)
        var c = Color(r: Self.mezcla(a.0, b.0, mv), g: Self.mezcla(a.1, b.1, mv), b: Self.mezcla(a.2, b.2, mv))
        c.r = Self.mezcla(c.r, 255, mw)
        c.g = Self.mezcla(c.g, 255, mw)
        c.b = Self.mezcla(c.b, 255, mw)
        let difusa = max(0, p.x * Self.luzSuave.0 + p.y * Self.luzSuave.1 + p.z * Self.luzSuave.2)
        c = Self.multiplicar(c, 0.92 + 0.08 * difusa)
        let canto = 0.24 * pow(1 - p.z, 2.5)
        c.r = Self.mezcla(c.r, borde.0, canto)
        c.g = Self.mezcla(c.g, borde.1, canto)
        c.b = Self.mezcla(c.b, borde.2, canto)
        let haciaLuz = max(0, p.x * Self.medioSuave.0 + p.y * Self.medioSuave.1 + p.z * Self.medioSuave.2)
        return Self.sumar(c, 255 * (0.18 * pow(haciaLuz, 6) + 0.2 * pow(1 - p.z, 7)))
    }

    // MARK: - De colores

    private func seda(_ p: Punto, _ g: Giro) -> Color {
        // Degradado de la muestra web: de un punto claro arriba a la izquierda a todo el círculo.
        let t = Self.degradadoFocal(p.x, p.y, focoX: -0.3, focoY: -0.35, radioFoco: 0.05)
        var c = Self.paleta(t, [(0, (242, 249, 255)), (0.5, (156, 204, 255)), (1, (59, 102, 227))])
        let orbita = 0.22 + 0.16 * g.energia
        let manchas: [((Double, Double, Double), Double, Double, Double, Double)] = [
            ((255, 255, 255), 0.85, 1.0, 0.0, 0.6),
            ((95, 210, 255), 0.8, -1.3, 2.1, 0.65),
            ((52, 86, 245), 0.75, 0.7, 4.2, 0.7),
        ]
        for (color, alfa, velocidad, salida, radio) in manchas {
            let angulo = g.fase * velocidad + salida
            c = Self.mancha(c, p, cos(angulo) * orbita, sin(angulo * 1.3) * orbita, radio, color, alfa, sumando: false)
        }
        return Self.acabado(c, p, sombra: (10, 20, 80), luz: 0.55)
    }

    private func nube(_ p: Punto, _ g: Giro) -> Color {
        let t = (p.y + 1) / 2
        var c = Self.paleta(t, [(0, (166, 220, 255)), (0.55, (61, 140, 255)), (1, (22, 80, 224))])
        let viaje = 0.35 + 0.25 * g.energia
        let nubes: [(Double, Double, Double)] = [(0.0, 0.55, 0.7), (1.7, 0.45, 0.6), (3.1, 0.6, 0.55), (4.4, 0.4, 0.65), (5.6, 0.5, 0.5)]
        for (indice, nube) in nubes.enumerated() {
            let angulo = g.fase * (0.5 + Double(indice) * 0.12) + nube.0
            let cx = sin(angulo) * viaje * 1.4
            let cy = cos(angulo * 0.8 + nube.0) * viaje
            c = Self.mancha(c, p, cx, cy, nube.1, (255, 255, 255), nube.2, sumando: false)
        }
        return Self.acabado(c, p, sombra: (6, 42, 122), luz: 0.4)
    }

    private func aurora(_ p: Punto, _ g: Giro) -> Color {
        let d = (p.x * p.x + p.y * p.y).squareRoot()
        var c = Self.paleta(d, [(0, (42, 31, 69)), (1, (6, 5, 11))])
        let orbita = 0.3 + 0.2 * g.energia
        let luces: [((Double, Double, Double), Double, Double)] = [
            ((255, 61, 154), 1.0, 0.0), ((138, 92, 255), -1.2, 1.6), ((41, 211, 255), 0.8, 3.2), ((255, 138, 61), -0.7, 4.7),
        ]
        for (color, velocidad, salida) in luces {
            let angulo = g.fase * velocidad + salida
            c = Self.mancha(c, p, cos(angulo) * orbita, sin(angulo) * orbita, 0.75, color, 0.75, sumando: true)
        }
        c = Self.acabado(c, p, sombra: (0, 0, 0), luz: 0.35)
        // Aro de colores que gira en el canto.
        let aro = Self.suave(0.95, 0.965, d)
        if aro > 0 {
            var vuelta = (atan2(p.y, p.x) - g.fase) / (2 * Double.pi)
            vuelta -= vuelta.rounded(.down)
            let colorAro = Self.paleta(vuelta, [
                (0, (255, 61, 154)), (0.25, (138, 92, 255)), (0.5, (41, 211, 255)), (0.75, (255, 138, 61)), (1, (255, 61, 154)),
            ])
            let fuerza = 0.7 * aro
            c.r = Self.mezcla(c.r, colorAro.r, fuerza)
            c.g = Self.mezcla(c.g, colorAro.g, fuerza)
            c.b = Self.mezcla(c.b, colorAro.b, fuerza)
        }
        return c
    }

    // MARK: - Piezas comunes

    /// Corrientes suaves que giran alrededor de la esfera: el dibujo se curva con ella y da volumen.
    private func corriente(_ p: Punto, _ g: Giro, escalaGiro: Double = 1, escalaTiempo: Double = 1) -> (Double, Double) {
        let t = g.fase * escalaTiempo
        let giro = (0.3 + 0.3 * g.energia) * escalaGiro
        let px = p.x * g.coseno + p.z * g.seno
        let pz = -p.x * g.seno + p.z * g.coseno
        let qx = px + giro * sin(1.9 * p.y + 0.8 * t)
        let qy = p.y + giro * cos(1.6 * pz - 0.6 * t)
        let v = 0.5 + 0.5 * sin(2.3 * qx + 1.7 * qy + 1.1 * pz + 1.3 * sin(1.5 * qy - 0.5 * t))
        let w = 0.5 + 0.5 * sin(-2.0 * qx + 1.9 * pz + 1.4 * qy + 0.7 * t)
        return (v, w)
    }

    /// Ruido de valores en 3D, de 0 a 1, suave entre los puntos de una rejilla con valores al azar.
    private static func ruido(_ x: Double, _ y: Double, _ z: Double) -> Double {
        let fx = x.rounded(.down), fy = y.rounded(.down), fz = z.rounded(.down)
        let ix = Int32(truncatingIfNeeded: Int(fx)), iy = Int32(truncatingIfNeeded: Int(fy)), iz = Int32(truncatingIfNeeded: Int(fz))
        let tx = x - fx, ty = y - fy, tz = z - fz
        let ux = tx * tx * (3 - 2 * tx), uy = ty * ty * (3 - 2 * ty), uz = tz * tz * (3 - 2 * tz)
        func valor(_ i: Int32, _ j: Int32, _ k: Int32) -> Double {
            var h = UInt32(bitPattern: i &* 73_856_093) ^ UInt32(bitPattern: j &* 19_349_663) ^ UInt32(bitPattern: k &* 83_492_791)
            h = (h ^ (h >> 16)) &* 0x7FEB_352D
            h = (h ^ (h >> 15)) &* 0x846C_A68B
            h ^= h >> 16
            return Double(h) / Double(UInt32.max)
        }
        let abajo = mezcla(
            mezcla(valor(ix, iy, iz), valor(ix + 1, iy, iz), ux),
            mezcla(valor(ix, iy + 1, iz), valor(ix + 1, iy + 1, iz), ux), uy
        )
        let arriba = mezcla(
            mezcla(valor(ix, iy, iz + 1), valor(ix + 1, iy, iz + 1), ux),
            mezcla(valor(ix, iy + 1, iz + 1), valor(ix + 1, iy + 1, iz + 1), ux), uy
        )
        return mezcla(abajo, arriba, uz)
    }

    /// Cuatro capas de ruido, cada una el doble de fina y la mitad de fuerte. De 0 a 1.
    private static func capas(_ x: Double, _ y: Double, _ z: Double) -> Double {
        var total = 0.0, fuerza = 0.5, escala = 1.0
        for _ in 0..<4 {
            total += fuerza * ruido(x * escala, y * escala, z * escala)
            fuerza *= 0.5
            escala *= 2
        }
        return total / 0.9375
    }

    /// La parte de abajo recibe menos luz.
    private func sombraAbajo(_ p: Punto) -> Double {
        1 - 0.22 * pow(max(0, p.y), 1.6)
    }

    /// El foco principal del estudio, visto reflejado: una mancha de luz nítida arriba a la izquierda.
    private func focoReflejado(_ p: Punto, _ anchoX: Double, _ anchoY: Double) -> Double {
        exp(-(pow(p.rx + 0.42, 2) / anchoX + pow(p.ry + 0.52, 2) / anchoY))
    }

    /// Estudio de fotografía: claro arriba, oscuro abajo, un foco grande arriba a la izquierda y luz de contorno a la derecha.
    static func estudio(_ rx: Double, _ ry: Double, _ rz: Double) -> Double {
        let arriba = suave(0.25, -0.9, ry)
        var e = 0.22 + 0.55 * arriba
        e -= 0.12 * suave(0.05, 0.9, ry)
        let foco = rz > -0.2 ? exp(-(pow(rx + 0.42, 2) / 0.035 + pow(ry + 0.52, 2) / 0.018)) : 0
        let contorno = exp(-(pow(rx - 0.78, 2) / 0.025 + pow(ry - 0.05, 2) / 0.12)) * 0.55
        return e + 1.15 * foco + contorno
    }

    /// El estudio que ven los metales: horizonte marcado, dos focos y luz rebotada abajo. La aspereza lo emborrona.
    static func estudioMetal(_ rx: Double, _ ry: Double, _ rz: Double, aspereza: Double) -> Double {
        let borroso = 0.04 + 0.35 * aspereza
        let cielo = 0.55 + 0.4 * suave(0.1, -0.9, ry)
        let suelo = 0.10 + 0.08 * suave(1, 0.2, ry)
        let horizonte = suave(0.06 + borroso, 0.06 - borroso, ry)
        var e = suelo + (cielo - suelo) * horizonte
        let ancho = 1 + 6 * aspereza
        if rz > -0.3 {
            e += exp(-(pow(rx + 0.45, 2) / (0.02 * ancho) + pow(ry + 0.55, 2) / (0.012 * ancho))) * 1.6 / (1 + 2 * aspereza)
        }
        e += exp(-(pow(rx - 0.65, 2) / (0.015 * ancho) + pow(ry + 0.25, 2) / (0.05 * ancho))) * 0.9 / (1 + 2 * aspereza)
        e += exp(-(pow(rx - 0.7, 2) / 0.05 + pow(ry - 0.45, 2) / 0.05)) * 0.35
        return e
    }

    /// Punto `t` de un degradado radial que nace en un círculo pequeño y acaba en el borde de la bola, como en un navegador.
    private static func degradadoFocal(_ x: Double, _ y: Double, focoX: Double, focoY: Double, radioFoco: Double) -> Double {
        let dx = -focoX, dy = -focoY, dr = 1 - radioFoco
        let qx = x - focoX, qy = y - focoY
        let a = dx * dx + dy * dy - dr * dr
        let b = -2 * (qx * dx + qy * dy + radioFoco * dr)
        let c = qx * qx + qy * qy - radioFoco * radioFoco
        let discriminante = max(0, b * b - 4 * a * c)
        let raiz = discriminante.squareRoot()
        let t = max((-b + raiz) / (2 * a), (-b - raiz) / (2 * a))
        return min(max(t, 0), 1)
    }

    /// Un círculo de color que se desvanece hacia fuera, encima o sumando luz.
    private static func mancha(
        _ c: Color, _ p: Punto, _ cx: Double, _ cy: Double, _ radio: Double,
        _ color: (Double, Double, Double), _ alfa: Double, sumando: Bool
    ) -> Color {
        let d = ((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy)).squareRoot()
        let fuerza = alfa * max(0, 1 - d / radio)
        guard fuerza > 0 else { return c }
        if sumando {
            return Color(r: c.r + color.0 * fuerza, g: c.g + color.1 * fuerza, b: c.b + color.2 * fuerza)
        }
        return Color(r: mezcla(c.r, color.0, fuerza), g: mezcla(c.g, color.1, fuerza), b: mezcla(c.b, color.2, fuerza))
    }

    /// Canto algo más oscuro y brillo de cristal arriba a la izquierda, como en la muestra web.
    private static func acabado(_ c: Color, _ p: Punto, sombra: (Double, Double, Double), luz: Double) -> Color {
        let d = (p.x * p.x + p.y * p.y).squareRoot()
        let fuerzaSombra = 0.4 * min(1, max(0, (d - 0.55) / 0.45))
        var r = mezcla(c.r, sombra.0, fuerzaSombra)
        var g = mezcla(c.g, sombra.1, fuerzaSombra)
        var b = mezcla(c.b, sombra.2, fuerzaSombra)
        let dh = ((p.x + 0.32) * (p.x + 0.32) + (p.y + 0.42) * (p.y + 0.42)).squareRoot()
        let fuerzaLuz = luz * max(0, 1 - dh / 0.65)
        r = mezcla(r, 255, fuerzaLuz)
        g = mezcla(g, 255, fuerzaLuz)
        b = mezcla(b, 255, fuerzaLuz)
        return Color(r: r, g: g, b: b)
    }

    private static func paleta(_ t: Double, _ paradas: [(Double, (Double, Double, Double))]) -> Color {
        guard let primera = paradas.first, let ultima = paradas.last else { return Color(r: 0, g: 0, b: 0) }
        if t <= primera.0 { return Color(r: primera.1.0, g: primera.1.1, b: primera.1.2) }
        for i in 1..<paradas.count where t <= paradas[i].0 {
            let (t0, c0) = paradas[i - 1]
            let (t1, c1) = paradas[i]
            let u = (t - t0) / (t1 - t0)
            return Color(r: mezcla(c0.0, c1.0, u), g: mezcla(c0.1, c1.1, u), b: mezcla(c0.2, c1.2, u))
        }
        return Color(r: ultima.1.0, g: ultima.1.1, b: ultima.1.2)
    }

    private static func multiplicar(_ c: Color, _ f: Double) -> Color {
        Color(r: c.r * f, g: c.g * f, b: c.b * f, a: c.a)
    }

    private static func sumar(_ c: Color, _ luz: Double) -> Color {
        Color(r: c.r + luz, g: c.g + luz, b: c.b + luz, a: c.a)
    }

    static func suave(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    static func mezcla(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private static func byte(_ valor: Double) -> UInt8 {
        UInt8(min(255, max(0, valor)).rounded())
    }

    private static func normalizar(_ x: Double, _ y: Double, _ z: Double) -> (Double, Double, Double) {
        let largo = (x * x + y * y + z * z).squareRoot()
        return (x / largo, y / largo, z / largo)
    }
}
