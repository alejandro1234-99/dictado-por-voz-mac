import AppKit
import Combine
import DictadoNucleo
import SwiftUI

/// La ventana de Oxidos OS, que empieza por el dictado: cristal sobre el escritorio, barra lateral flotante y una sección a la derecha.
final class VentanaPrincipal {
    private var ventana: NSWindow?
    private var suscripcion: AnyCancellable?

    func mostrar(estado: EstadoApp, en seccion: Seccion? = nil) {
        if let seccion {
            estado.seccion = seccion
        }
        if ventana == nil {
            ventana = crear(estado: estado)
        }
        DatosApp.compartido.recargar()
        // Con la app en segundo plano, macOS puede dejarla detrás de la app que está delante: se trae a la fuerza.
        NSApp.activate()
        ventana?.makeKeyAndOrderFront(nil)
        ventana?.orderFrontRegardless()
    }

    private func crear(estado: EstadoApp) -> NSWindow {
        let controlador = NSHostingController(rootView: VistaPrincipal(estado: estado, datos: DatosApp.compartido))
        // El tamaño lo decide la ventana, no el contenido: así se puede agrandar y achicar.
        controlador.sizingOptions = []
        let ventana = NSWindow(contentViewController: controlador)
        ventana.title = "Oxidos OS"
        ventana.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        ventana.titlebarAppearsTransparent = true
        ventana.titleVisibility = .hidden
        // Transparente: el fondo es cristal que deja ver el escritorio desenfocado.
        ventana.isOpaque = false
        ventana.backgroundColor = .clear
        ventana.isMovableByWindowBackground = true
        ventana.isReleasedWhenClosed = false
        ventana.minSize = NSSize(width: 900, height: 620)
        ventana.setContentSize(NSSize(width: 1060, height: 720))
        ventana.setFrameAutosaveName("Dictado.ventana")
        ventana.center()
        // Con el fondo azul, la ventana va siempre en claro, como en el diseño, aunque el Mac esté en modo oscuro.
        suscripcion = estado.$fondoVentana.sink { [weak ventana] fondo in
            ventana?.appearance = fondo == .azul ? NSAppearance(named: .aqua) : nil
        }
        return ventana
    }
}

struct VistaPrincipal: View {
    @ObservedObject var estado: EstadoApp
    @ObservedObject var datos: DatosApp

    init(estado: EstadoApp, datos: DatosApp) {
        self.estado = estado
        self.datos = datos
    }

    var body: some View {
        HStack(spacing: 0) {
            BarraLateral(estado: estado, datos: datos)
                .frame(width: 252)
                .padding(10)
            ScrollView {
                contenido
                    .padding(.horizontal, 22)
                    .padding(.top, 40)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .background(FondoDictado(fondo: estado.fondoVentana))
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var contenido: some View {
        switch estado.seccion {
        case .inicio: VistaInicio(estado: estado, datos: datos)
        case .historial: VistaHistorial(datos: datos)
        case .diccionario: VistaDiccionario(datos: datos)
        case .estilo: VistaEstilo(estado: estado)
        case .bola: VistaAjustesBola(estado: estado)
        case .ajustes: VistaAjustes(estado: estado)
        }
    }
}

/// Barra lateral de cristal que flota dentro de la ventana, como en macOS 26. Textos grandes y cada icono en su
/// baldosa: la sección elegida, con la baldosa en el azul de la bola.
private struct BarraLateral: View {
    @ObservedObject var estado: EstadoApp
    @ObservedObject var datos: DatosApp

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Hueco para los botones de cerrar, minimizar y ampliar.
            Spacer().frame(height: 34)
            HStack(spacing: 12) {
                BolaAnimada(apariencia: estado.bola, diametro: 38)
                    .shadow(color: Color.black.opacity(0.25), radius: 5, y: 4)
                Text("Oxidos OS")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.3)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 18)

            ForEach(Seccion.allCases) { seccion in
                boton(seccion)
            }

            Spacer()

            pie
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    /// Abajo: las palabras de hoy y cómo dictar, o qué falta.
    private var pie: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(estado.faltanPermisos ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(estado.faltanPermisos ? "Faltan permisos" : "Listo para dictar")
                    .font(.system(size: 13, weight: .semibold))
            }
            if !estado.faltanPermisos {
                HStack(spacing: 6) {
                    Text("Mantén")
                    Text(estado.atajo.nombre)
                        .font(.system(size: 12.5, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: Color.black.opacity(0.12), radius: 0.5, y: 1)
                        )
                    Text("y habla")
                }
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                Text("\(Metricas.cifra(datos.metricas.hoy)) palabras hoy")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        )
    }

    private func boton(_ seccion: Seccion) -> some View {
        let elegida = estado.seccion == seccion
        return Button {
            estado.seccion = seccion
        } label: {
            HStack(spacing: 12) {
                Image(systemName: seccion.icono)
                    .symbolVariant(elegida ? .fill : .none)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(elegida ? Color.white : Color.acento)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                elegida
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [Color.acento.opacity(0.85), Color.acento],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    : AnyShapeStyle(Color.acento.opacity(0.1))
                            )
                            .shadow(color: elegida ? Color.acento.opacity(0.35) : Color.clear, radius: 4, y: 2)
                    )
                Text(seccion.nombre)
                    .font(.system(size: 15, weight: elegida ? .semibold : .medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                if elegida {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// El fondo de la ventana. El cristal brilla cuando tiene color detrás: con el fondo azul, sobre el escritorio
/// desenfocado van las luces azules del diseño y un velo claro.
private struct FondoDictado: View {
    let fondo: FondoDeVentana

    var body: some View {
        ZStack {
            FondoVentana()
            if fondo == .azul {
                GeometryReader { geometria in
                    let lado = max(geometria.size.width, geometria.size.height)
                    ZStack {
                        LinearGradient(
                            colors: [Self.color(0xDB, 0xE8, 0xF8), Self.color(0x4F, 0x7F, 0xC4), Self.color(0x18, 0x3C, 0x7A)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Self.luz(Color.white.opacity(0.85), x: 0.12, y: 0.18, radio: 0.40 * lado)
                        Self.luz(Self.color(120, 190, 255).opacity(0.95), x: 0.78, y: 0.22, radio: 0.35 * lado)
                        Self.luz(Self.color(18, 70, 170).opacity(0.95), x: 0.30, y: 0.88, radio: 0.44 * lado)
                        Self.luz(Self.color(40, 150, 200).opacity(0.85), x: 0.92, y: 0.78, radio: 0.32 * lado)
                        Self.luz(Self.color(255, 214, 170).opacity(0.55), x: 0.55, y: 0.52, radio: 0.26 * lado)
                        // El velo claro del cristal de la ventana.
                        Color(white: 0.97).opacity(0.42)
                    }
                    .opacity(0.94)
                }
            }
        }
        .ignoresSafeArea()
    }

    private static func luz(_ color: Color, x: CGFloat, y: CGFloat, radio: CGFloat) -> some View {
        RadialGradient(
            colors: [color, color.opacity(0)],
            center: UnitPoint(x: x, y: y),
            startRadius: 0,
            endRadius: radio
        )
    }

    private static func color(_ rojo: Double, _ verde: Double, _ azul: Double) -> Color {
        Color(red: rojo / 255, green: verde / 255, blue: azul / 255)
    }
}

/// El fondo de la ventana: cristal que deja ver el escritorio muy desenfocado.
private struct FondoVentana: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let vista = NSVisualEffectView()
        vista.material = .underWindowBackground
        vista.blendingMode = .behindWindow
        vista.state = .active
        return vista
    }

    func updateNSView(_ vista: NSVisualEffectView, context: Context) {}
}
