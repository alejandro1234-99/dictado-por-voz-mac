import AppKit
import DictadoNucleo
import SwiftUI

/// Lo que se ve mientras se dicta: una bola pintada punto a punto o una cápsula con barras, según los ajustes.
/// La usan el panel flotante y la vista previa de los ajustes.
struct VistaIndicador: View {
    let apariencia: AparienciaBola
    let nivel: NivelVoz
    @State private var dentro = false

    init(apariencia: AparienciaBola, nivel: NivelVoz) {
        self.apariencia = apariencia
        self.nivel = nivel
    }

    /// Lado del panel cuadrado: cabe la bola en su tamaño mayor y la luz de alrededor.
    static func lado(para apariencia: AparienciaBola) -> CGFloat {
        if apariencia.estilo.esCapsula {
            return CGFloat(112 * apariencia.tamano / 52) + 48
        }
        return CGFloat(apariencia.tamano * 2.4)
    }

    /// Alto de lo que se ve, sin la luz de alrededor: sirve para colocarla a la misma distancia del borde.
    static func altoVisible(para apariencia: AparienciaBola) -> CGFloat {
        switch apariencia.estilo {
        case .capsulaCompacta: return CGFloat(40 * apariencia.tamano / 52)
        case .capsulaCristal, .capsulaGrafito: return CGFloat(34 * apariencia.tamano / 52)
        default: return CGFloat(apariencia.tamano)
        }
    }

    var body: some View {
        Group {
            if apariencia.estilo.esCapsula {
                // Al cambiar de cápsula cambia el número de barras: vista nueva.
                VistaCapsula(apariencia: apariencia, nivel: nivel)
                    .id(apariencia.estilo)
            } else {
                VistaBolaPintada(apariencia: apariencia, nivel: nivel)
            }
        }
        .frame(width: Self.lado(para: apariencia), height: Self.lado(para: apariencia))
        .scaleEffect(dentro ? 1 : 0.85)
        .opacity(dentro ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                dentro = true
            }
        }
    }
}

/// La bola elegida, para la ventana: en calma, y al pasar el ratón por encima se mueve como si se hablara.
/// Las cápsulas no son bolas: en su lugar sale la perla. Quieta, se pinta una sola vez.
struct BolaAnimada: View {
    let apariencia: AparienciaBola
    let diametro: CGFloat
    var animada = true
    @State private var giro = GiroBola()
    @State private var taller = TallerBola()
    @State private var encima = false

    init(apariencia: AparienciaBola, diametro: CGFloat, animada: Bool = true) {
        self.apariencia = apariencia
        self.diametro = diametro
        self.animada = animada
    }

    private var aparienciaPintada: AparienciaBola {
        var pintada = apariencia
        if pintada.estilo.esCapsula { pintada.estilo = .perla }
        pintada.tamano = Double(diametro)
        return pintada
    }

    var body: some View {
        Group {
            if animada {
                TimelineView(.animation) { contexto in
                    let voz = encima ? 0.45 + 0.4 * abs(sin(contexto.date.timeIntervalSinceReferenceDate * 7)) : 0
                    let _ = giro.avanzar(a: contexto.date, nivel: voz)
                    imagen(fase: giro.fase, energia: giro.energia)
                }
            } else {
                imagen(fase: 1.3, energia: 0)
            }
        }
        .frame(width: diametro, height: diametro)
        .onHover { encima = $0 }
    }

    @ViewBuilder
    private func imagen(fase: Double, energia: Double) -> some View {
        if let imagen = taller.imagen(apariencia: aparienciaPintada, fase: fase, energia: energia) {
            Image(decorative: imagen, scale: 1)
                .resizable()
                .interpolation(.high)
        }
    }
}

/// Guarda el pintor del tamaño actual y convierte cada fotograma en una imagen.
final class TallerBola {
    /// Píxeles por punto: 1,5 se ve suave en pantallas Retina y deja el fotograma en pocos milisegundos.
    static let densidad = 1.5
    private var pintor: PintorBola?

    func imagen(apariencia: AparienciaBola, fase: Double, energia: Double) -> CGImage? {
        let lado = Int((apariencia.tamano * Self.densidad).rounded())
        if pintor?.lado != lado {
            pintor = PintorBola(lado: lado)
        }
        guard let pintor else { return nil }
        pintor.pintar(estilo: apariencia.estilo, fase: fase, energia: energia, brillo: apariencia.brillo)
        return pintor.imagen()
    }
}

extension PintorBola {
    func imagen() -> CGImage? {
        let datos = Data(pixeles) as CFData
        guard let proveedor = CGDataProvider(data: datos), let espacio = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        return CGImage(
            width: lado,
            height: lado,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: lado * 4,
            space: espacio,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: proveedor,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

extension EstiloBola {
    var colorLuz: Color {
        let (rojo, verde, azul) = colorHalo
        return Color(red: rojo, green: verde, blue: azul)
    }
}

/// La bola: crece un poco y gira más deprisa con la voz. Detrás, la luz de alrededor; debajo, una sombra suave.
private struct VistaBolaPintada: View {
    let apariencia: AparienciaBola
    let nivel: NivelVoz
    @State private var giro = GiroBola()
    @State private var taller = TallerBola()

    var body: some View {
        TimelineView(.animation) { contexto in
            let _ = giro.avanzar(a: contexto.date, nivel: nivel.leer())
            let energia = giro.energia
            let diametro = CGFloat(apariencia.tamano * (1 + 0.12 * energia))
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [apariencia.estilo.colorLuz.opacity(apariencia.halo * (0.55 + 0.45 * energia)), Color.clear],
                        center: .center,
                        startRadius: diametro * 0.35,
                        endRadius: diametro * 1.15
                    ))
                    .frame(width: diametro * 2.3, height: diametro * 2.3)
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color.black.opacity(0.26), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: diametro * 0.55
                    ))
                    .frame(width: diametro * 1.1, height: diametro * 0.3)
                    .offset(y: diametro * 0.52)
                if let imagen = taller.imagen(apariencia: apariencia, fase: giro.fase, energia: energia) {
                    Image(decorative: imagen, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: diametro, height: diametro)
                }
            }
        }
    }
}

/// Cápsula con barras que siguen la voz: de cristal, que deja ver desenfocado lo de detrás, o de grafito.
private struct VistaCapsula: View {
    let apariencia: AparienciaBola
    let nivel: NivelVoz
    @State private var barras: BarrasVoz

    init(apariencia: AparienciaBola, nivel: NivelVoz) {
        self.apariencia = apariencia
        self.nivel = nivel
        _barras = State(initialValue: BarrasVoz(cuantas: apariencia.estilo == .capsulaCompacta ? 5 : 9))
    }

    var body: some View {
        let escala = CGFloat(apariencia.tamano / 52)
        let compacta = apariencia.estilo == .capsulaCompacta
        let grafito = apariencia.estilo == .capsulaGrafito
        let ancho = (compacta ? 40 : 112) * escala
        let alto = (compacta ? 40 : 34) * escala
        let minima = 3 * escala
        let maxima = 22 * escala
        return TimelineView(.animation) { contexto in
            let _ = barras.avanzar(a: contexto.date, nivel: nivel.leer(), escuchando: nivel.escuchando)
            HStack(spacing: (compacta ? 2.5 : 3) * escala) {
                ForEach(0..<barras.cuantas, id: \.self) { indice in
                    Capsule()
                        .fill(grafito ? Color.white.opacity(0.95) : Color.primary.opacity(0.85))
                        .frame(width: minima, height: minima + (maxima - minima) * CGFloat(barras.alturas[indice]))
                }
            }
            .frame(width: ancho, height: alto)
            .background {
                if grafito {
                    LinearGradient(
                        colors: [Color(white: 0.24), Color(white: 0.11)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    VidrioDetras()
                }
            }
            .clipShape(Capsule())
            // Filo de luz arriba y aro finísimo: el relieve de los botones de macOS.
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(grafito ? 0.22 : 0.6), Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1
                )
            )
            .overlay(Capsule().strokeBorder(Color.black.opacity(grafito ? 0.6 : 0.12), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.12), radius: 1, y: 1)
            .shadow(color: Color.black.opacity(grafito ? 0.4 : 0.25), radius: 12 * escala, y: 6 * escala)
            .opacity(apariencia.brillo >= 1 ? 1 : 0.75 + 0.25 * apariencia.brillo)
        }
    }
}

/// Cristal de macOS: desenfoca lo que hay detrás de la ventana y se adapta al modo claro u oscuro.
private struct VidrioDetras: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let vista = NSVisualEffectView()
        vista.material = .popover
        vista.blendingMode = .behindWindow
        vista.state = .active
        return vista
    }

    func updateNSView(_ vista: NSVisualEffectView, context: Context) {}
}
