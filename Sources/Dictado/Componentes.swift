import AppKit
import DictadoNucleo
import SwiftUI

/// El azul de la bola: el único color de acento de la ventana.
extension Color {
    static let acento = Color(red: 0.18, green: 0.42, blue: 0.93)
}

/// Pieza de cristal de macOS 26, Liquid Glass, con su relleno y sus esquinas.
struct Cristal: ViewModifier {
    var radio: CGFloat = 18
    var relleno: CGFloat = 18
    var oscuro = false

    func body(content: Content) -> some View {
        content
            .padding(relleno)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                oscuro ? .regular.tint(Color.black.opacity(0.55)) : .regular,
                in: .rect(cornerRadius: radio)
            )
    }
}

extension View {
    func cristal(radio: CGFloat = 18, relleno: CGFloat = 18, oscuro: Bool = false) -> some View {
        modifier(Cristal(radio: radio, relleno: relleno, oscuro: oscuro))
    }
}

/// Título de una sección de la ventana.
struct TituloSeccion<Accesorio: View>: View {
    let titulo: String
    @ViewBuilder let accesorio: () -> Accesorio

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(titulo)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.6)
            Spacer()
            accesorio()
        }
    }
}

extension TituloSeccion where Accesorio == EmptyView {
    init(_ titulo: String) {
        self.titulo = titulo
        self.accesorio = { EmptyView() }
    }
}

/// Etiqueta en forma de píldora, de cristal.
struct Etiqueta: View {
    let texto: String
    var claro = false

    var body: some View {
        Text(texto)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(claro ? Color.white : Color.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .glassEffect(claro ? .regular.tint(Color.white.opacity(0.08)) : .regular, in: .capsule)
    }
}

/// El icono de verdad de la app en la que se dictó, o su inicial si no está en el Mac.
struct IconoApp: View {
    let bundle: String?
    let nombre: String?
    var lado: CGFloat = 28

    var body: some View {
        if let imagen = Self.icono(bundle) {
            Image(nsImage: imagen)
                .resizable()
                .frame(width: lado, height: lado)
        } else {
            Text(String((nombre ?? "?").prefix(1)).uppercased())
                .font(.system(size: lado * 0.45, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: lado, height: lado)
                .background(RoundedRectangle(cornerRadius: lado * 0.25, style: .continuous).fill(Color.gray))
        }
    }

    private static var guardados: [String: NSImage] = [:]

    private static func icono(_ bundle: String?) -> NSImage? {
        guard let bundle else { return nil }
        if let guardado = guardados[bundle] { return guardado }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return nil }
        let imagen = NSWorkspace.shared.icon(forFile: url.path)
        guardados[bundle] = imagen
        return imagen
    }
}

/// Coloca las vistas en filas que saltan de línea cuando no caben, como las etiquetas del diccionario.
struct FilasQueFluyen: Layout {
    var espacio: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ancho = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var altoFila: CGFloat = 0
        var anchoMaximo: CGFloat = 0
        for vista in subviews {
            let tamano = vista.sizeThatFits(.unspecified)
            if x > 0 && x + tamano.width > ancho {
                y += altoFila + espacio
                x = 0
                altoFila = 0
            }
            x += tamano.width + espacio
            altoFila = max(altoFila, tamano.height)
            anchoMaximo = max(anchoMaximo, x - espacio)
        }
        return CGSize(width: proposal.width ?? anchoMaximo, height: y + altoFila)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var altoFila: CGFloat = 0
        for vista in subviews {
            let tamano = vista.sizeThatFits(.unspecified)
            if x > bounds.minX && x + tamano.width > bounds.maxX {
                y += altoFila + espacio
                x = bounds.minX
                altoFila = 0
            }
            vista.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(tamano))
            x += tamano.width + espacio
            altoFila = max(altoFila, tamano.height)
        }
    }
}

/// Envuelve FilasQueFluyen para usarlo como cualquier contenedor: `Fluir { ... }`.
struct Fluir<Contenido: View>: View {
    var espacio: CGFloat = 8
    @ViewBuilder let contenido: () -> Contenido

    var body: some View {
        FilasQueFluyen(espacio: espacio).callAsFunction(contenido)
    }
}

/// Una fila de permiso: qué es, para qué sirve y si está concedido.
struct FilaPermiso: View {
    let icono: String
    let titulo: String
    let detalle: String
    let concedido: Bool
    let pedir: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icono)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                Text(detalle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if concedido {
                Label("Concedido", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Permitir", action: pedir)
                    .buttonStyle(.glassProminent)
            }
        }
    }
}

/// Enseña el atajo y, al pulsarlo, graba el siguiente que se pulse. Esc deja el que había.
struct BotonAtajo: View {
    @Binding var atajo: Atajo
    @Binding var aviso: String?
    @State private var grabando = false
    @State private var enCurso: Modificadores = []
    @State private var grabacion = GrabacionAtajo()
    @State private var monitor: Any?

    init(atajo: Binding<Atajo>, aviso: Binding<String?>) {
        _atajo = atajo
        _aviso = aviso
    }

    var body: some View {
        Button(action: alternar) {
            Text(texto)
                .frame(minWidth: 110)
        }
        .buttonStyle(.glass)
        .onDisappear(perform: parar)
    }

    private var texto: String {
        guard grabando else { return atajo.nombre }
        return enCurso.isEmpty ? "Pulsa el atajo…" : enCurso.simbolos + "…"
    }

    private func alternar() {
        if grabando {
            parar()
        } else {
            empezar()
        }
    }

    private func empezar() {
        grabacion = GrabacionAtajo()
        enCurso = []
        aviso = nil
        grabando = true
        Tecla.enPausa = true
        // Mientras graba, las teclas se quedan aquí: ni dictan ni llegan a la ventana.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { evento in
            recibir(evento)
            return nil
        }
    }

    private func parar() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        grabando = false
        enCurso = []
        Tecla.enPausa = false
    }

    private func recibir(_ evento: NSEvent) {
        let modificadores = Self.modificadores(evento.modifierFlags)
        let resultado: GrabacionAtajo.Resultado?
        switch evento.type {
        case .flagsChanged:
            enCurso = modificadores
            resultado = grabacion.recibir(.modificadores(modificadores))
        case .keyDown:
            // Solo las pulsaciones de tecla traen caracteres: pedirlos en otro evento cierra la app.
            resultado = grabacion.recibir(
                .abajo(tecla: evento.keyCode, modificadores: modificadores, repetida: evento.isARepeat),
                nombreTecla: evento.charactersIgnoringModifiers
            )
        default:
            resultado = nil
        }

        switch resultado {
        case .listo(let nuevo)?:
            atajo = nuevo
            aviso = nil
            parar()
        case .cancelado?:
            parar()
        case .rechazado(let problema)?:
            aviso = problema.explicacion
            enCurso = []
        case nil:
            break
        }
    }

    private static func modificadores(_ flags: NSEvent.ModifierFlags) -> Modificadores {
        var modificadores: Modificadores = []
        if flags.contains(.control) { modificadores.insert(.control) }
        if flags.contains(.option) { modificadores.insert(.opcion) }
        if flags.contains(.shift) { modificadores.insert(.mayusculas) }
        if flags.contains(.command) { modificadores.insert(.comando) }
        if flags.contains(.function) { modificadores.insert(.fn) }
        return modificadores
    }
}
