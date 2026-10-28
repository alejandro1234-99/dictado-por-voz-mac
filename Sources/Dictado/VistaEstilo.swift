import DictadoNucleo
import SwiftUI

extension TipoApp {
    var nombreCorto: String {
        switch self {
        case .personal: return "Personal"
        case .trabajo: return "Trabajo"
        case .email: return "Correo"
        case .otras: return "Otras"
        }
    }
}

/// Estilo: cómo se escribe en cada tipo de app, con un mensaje de muestra en cada estilo.
struct VistaEstilo: View {
    @ObservedObject var estado: EstadoApp
    @State private var tipo: TipoApp = .personal

    init(estado: EstadoApp) {
        self.estado = estado
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TituloSeccion(titulo: "Estilo") {
                Picker("Tipo de app", selection: $tipo) {
                    ForEach(TipoApp.allCases, id: \.self) { tipo in
                        Text(tipo.nombreCorto).tag(tipo)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 340)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(EstiloEscritura.allCases, id: \.self) { estilo in
                    TarjetaEstilo(estilo: estilo, elegido: estado.estilos[tipo] == estilo) {
                        estado.estilos[tipo] = estilo
                    }
                }
            }

            HStack {
                Text("El texto aparece")
                Spacer()
                Picker("El texto aparece", selection: $estado.escrituraProgresiva) {
                    Text("Palabra a palabra").tag(true)
                    Text("De golpe").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
            }
            .cristal(relleno: 14)
        }
    }
}

private struct TarjetaEstilo: View {
    let estilo: EstiloEscritura
    let elegido: Bool
    let elegir: () -> Void

    var body: some View {
        Button(action: elegir) {
            VStack(alignment: .leading, spacing: 10) {
                Text(estilo.nombre)
                    .font(.system(size: 14, weight: .semibold))
                // El mensaje de muestra, en bocadillo, escrito con este estilo.
                Text(estilo.ejemplo)
                    .font(.system(size: 13.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16, bottomLeadingRadius: 5, bottomTrailingRadius: 16, topTrailingRadius: 16,
                            style: .continuous
                        )
                        .fill(Color.primary.opacity(0.07))
                    )
            }
            .cristal()
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(elegido ? Color.acento : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
