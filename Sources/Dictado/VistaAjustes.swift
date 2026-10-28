import DictadoNucleo
import SwiftUI

/// Ajustes: permisos, atajo y abrir al iniciar sesión.
struct VistaAjustes: View {
    @ObservedObject var estado: EstadoApp
    @State private var avisoAtajo: String?

    init(estado: EstadoApp) {
        self.estado = estado
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TituloSeccion("Ajustes")

            VStack(alignment: .leading, spacing: 10) {
                Text("Permisos")
                    .font(.system(size: 13, weight: .semibold))
                FilaPermiso(
                    icono: "mic",
                    titulo: "Micrófono",
                    detalle: "Solo mientras pulsas la tecla.",
                    concedido: estado.microConcedido
                ) {
                    Permisos.pedirMicro { estado.microConcedido = $0 }
                }
                Divider().opacity(0.5)
                FilaPermiso(
                    icono: "accessibility",
                    titulo: "Accesibilidad",
                    detalle: "Para la tecla y para escribir donde está el cursor.",
                    concedido: estado.accesibilidadConcedida
                ) {
                    Permisos.pedirAccesibilidad()
                }
            }
            .cristal()

            VStack(alignment: .leading, spacing: 10) {
                Text("Dictar")
                    .font(.system(size: 13, weight: .semibold))
                HStack {
                    Text("Atajo")
                    Spacer()
                    if estado.atajo != .fn {
                        Button("Usar Fn") { estado.atajo = .fn }
                            .buttonStyle(.borderless)
                    }
                    BotonAtajo(atajo: $estado.atajo, aviso: $avisoAtajo)
                }
                if let avisoAtajo {
                    Text(avisoAtajo)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if estado.atajo == .fn {
                    HStack(alignment: .firstTextBaseline) {
                        Text("En Teclado, pon «Pulsar la tecla 🌐 para» en «No hacer nada».")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Abrir Teclado") { Permisos.abrir(.teclado) }
                            .buttonStyle(.glass)
                    }
                }
                Divider().opacity(0.5)
                HStack {
                    Text("Abrir al iniciar sesión")
                    Spacer()
                    Toggle("Abrir al iniciar sesión", isOn: $estado.abrirAlIniciar)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
            .cristal()

            HStack {
                Text("Fondo de la ventana")
                Spacer()
                Picker("Fondo de la ventana", selection: $estado.fondoVentana) {
                    ForEach(FondoDeVentana.allCases) { fondo in
                        Text(fondo.nombre).tag(fondo)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }
            .cristal(relleno: 14)
        }
    }
}
