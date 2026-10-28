import DictadoNucleo
import SwiftUI

/// Sección «Bola» de la ventana: vista previa, tamaño, luz, brillo, posición y estilo, en piezas de cristal.
struct VistaAjustesBola: View {
    @ObservedObject var estado: EstadoApp

    init(estado: EstadoApp) {
        self.estado = estado
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TituloSeccion(titulo: "Bola") {
                Button("Restablecer") { estado.bola = .estandar }
                    .buttonStyle(.glass)
            }

            VistaPrevia(apariencia: estado.bola)
                .cristal(radio: 22, relleno: 14)

            VStack(spacing: 12) {
                fila("Tamaño") {
                    Slider(value: $estado.bola.tamano, in: AparienciaBola.tamanos, step: 2)
                }
                fila("Luz alrededor") {
                    Slider(value: $estado.bola.halo, in: 0...1)
                }
                fila("Brillo") {
                    Slider(value: $estado.bola.brillo, in: AparienciaBola.brillos)
                }
                fila("Posición") {
                    Picker("Posición", selection: $estado.bola.posicion) {
                        ForEach(PosicionBola.allCases, id: \.self) { posicion in
                            Text(posicion.nombre).tag(posicion)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 200, alignment: .leading)
                    Spacer()
                }
            }
            .cristal()

            ForEach(EstiloBola.Familia.allCases, id: \.self) { familia in
                VStack(alignment: .leading, spacing: 10) {
                    Text(familia.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                    LazyVGrid(columns: Self.columnas, alignment: .leading, spacing: 10) {
                        ForEach(EstiloBola.de(familia), id: \.self) { estilo in
                            Miniatura(estilo: estilo, elegido: estado.bola.estilo == estilo) {
                                estado.bola.estilo = estilo
                            }
                        }
                    }
                }
                .cristal()
            }
        }
    }

    private func fila<Control: View>(_ titulo: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 14) {
            Text(titulo)
                .frame(width: 110, alignment: .leading)
            control()
        }
    }

    private static let columnas = [GridItem(.adaptive(minimum: 64, maximum: 72), spacing: 10)]
}

/// La bola tal como saldrá, sobre un trozo de escritorio. Mientras se mantiene el botón, se mueve como si se hablara.
private struct VistaPrevia: View {
    let apariencia: AparienciaBola
    @State private var simulador = SimuladorVoz()
    @State private var hablando = false

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.animation) { contexto in
                let _ = simulador.avanzar(a: contexto.date, hablando: hablando)
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.87, green: 0.90, blue: 0.93), Color(red: 0.68, green: 0.74, blue: 0.81)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VistaIndicador(apariencia: apariencia, nivel: simulador.nivel)
                        .scaleEffect(min(1, 190 / VistaIndicador.lado(para: apariencia)))
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text(hablando ? "Hablando…" : "Mantén para probar")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.primary.opacity(hablando ? 0.14 : 0.08)))
                .contentShape(Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in hablando = true }
                        .onEnded { _ in hablando = false }
                )
        }
        .frame(maxWidth: .infinity)
    }
}

/// Alimenta la vista previa con una voz de prueba mientras se mantiene el botón.
private final class SimuladorVoz {
    let nivel = NivelVoz()
    private let voz = VozSimulada()
    private var ultima: Date?

    func avanzar(a fecha: Date, hablando: Bool) {
        let paso = ultima.map { min(max(fecha.timeIntervalSince($0), 0), 0.1) } ?? 0
        ultima = fecha
        nivel.poner(hablando ? voz.nivel(tras: paso) : 0)
    }
}

/// Un estilo en pequeño, para elegirlo con un clic.
private struct Miniatura: View {
    let estilo: EstiloBola
    let elegido: Bool
    let elegir: () -> Void

    var body: some View {
        Button(action: elegir) {
            VStack(spacing: 4) {
                dibujo
                    .frame(width: 44, height: 44)
                Text(estilo.nombre)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 64, height: 68)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(elegido ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(elegido ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(estilo.nombre)
    }

    @ViewBuilder
    private var dibujo: some View {
        if estilo.esCapsula {
            CapsulaQuieta(estilo: estilo)
        } else if let imagen = Miniaturas.imagen(de: estilo) {
            Image(decorative: imagen, scale: 2)
                .resizable()
                .interpolation(.high)
        }
    }
}

/// Las miniaturas de las bolas se pintan una vez y se guardan.
private enum Miniaturas {
    private static var guardadas: [EstiloBola: CGImage] = [:]

    static func imagen(de estilo: EstiloBola) -> CGImage? {
        if let imagen = guardadas[estilo] {
            return imagen
        }
        let pintor = PintorBola(lado: 88)
        pintor.pintar(estilo: estilo, fase: 1.3, energia: 0.2)
        let imagen = pintor.imagen()
        guardadas[estilo] = imagen
        return imagen
    }
}

/// La cápsula en pequeño y quieta, con las barras en forma de campana.
private struct CapsulaQuieta: View {
    let estilo: EstiloBola
    private static let alturas: [CGFloat] = [4, 7, 11, 14, 16, 14, 11, 7, 4]

    var body: some View {
        let compacta = estilo == .capsulaCompacta
        let grafito = estilo == .capsulaGrafito
        let alturas = compacta ? [6, 11, 15, 11, 6] : Self.alturas
        return HStack(spacing: 2) {
            ForEach(0..<alturas.count, id: \.self) { indice in
                Capsule()
                    .fill(grafito ? Color.white : Color.primary.opacity(0.8))
                    .frame(width: 2, height: alturas[indice] * 0.6)
            }
        }
        .frame(width: compacta ? 26 : 44, height: compacta ? 26 : 16)
        .background(
            Capsule().fill(grafito ? Color(white: 0.18) : Color.primary.opacity(0.08))
        )
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
    }
}
