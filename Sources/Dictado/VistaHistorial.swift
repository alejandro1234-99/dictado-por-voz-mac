import DictadoNucleo
import SwiftUI

/// Historial: los dictados por días, con buscador. Cada uno se copia, se ve como lo dio el motor o se borra.
struct VistaHistorial: View {
    @ObservedObject var datos: DatosApp
    @State private var busqueda = ""

    init(datos: DatosApp) {
        self.datos = datos
    }

    private struct Dia: Identifiable {
        let dia: Date
        let dictados: [DictadoGuardado]
        var id: Date { dia }
    }

    var body: some View {
        // Se vuelve a leer cuando cambian los datos o la búsqueda.
        let dias = Self.porDias(datos.historial(buscando: busqueda))
        VStack(alignment: .leading, spacing: 14) {
            TituloSeccion(titulo: "Historial") {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar", text: $busqueda)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(width: 240)
                .glassEffect(.regular, in: .capsule)
            }

            if dias.isEmpty {
                Text(busqueda.isEmpty ? "Aún no hay dictados." : "Ningún dictado con «\(busqueda)».")
                    .foregroundStyle(.secondary)
                    .cristal()
            }

            ForEach(dias) { dia in
                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.titulo(dia.dia))
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.bottom, 4)
                    ForEach(Array(dia.dictados.enumerated()), id: \.element.id) { indice, dictado in
                        if indice > 0 {
                            Divider().opacity(0.5)
                        }
                        FilaHistorial(dictado: dictado) { datos.borrar(dictado) }
                    }
                }
                .cristal()
            }
        }
    }

    private static func porDias(_ dictados: [DictadoGuardado]) -> [Dia] {
        let calendario = Calendar.current
        let grupos = Dictionary(grouping: dictados) { calendario.startOfDay(for: $0.fecha) }
        return grupos.keys.sorted(by: >).map { Dia(dia: $0, dictados: grupos[$0] ?? []) }
    }

    private static let formatoDia: DateFormatter = {
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "es_ES")
        formato.dateFormat = "EEEE d 'de' MMMM"
        return formato
    }()

    private static func titulo(_ dia: Date) -> String {
        let calendario = Calendar.current
        if calendario.isDateInToday(dia) { return "Hoy" }
        if calendario.isDateInYesterday(dia) { return "Ayer" }
        let texto = formatoDia.string(from: dia)
        return texto.prefix(1).uppercased() + texto.dropFirst()
    }
}

private struct FilaHistorial: View {
    let dictado: DictadoGuardado
    let borrar: () -> Void
    @State private var verCrudo = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconoApp(bundle: dictado.appBundle, nombre: dictado.app)
            VStack(alignment: .leading, spacing: 4) {
                Text(dictado.texto)
                    .lineLimit(verCrudo ? nil : 3)
                    .textSelection(.enabled)
                if verCrudo, let crudo = dictado.crudo {
                    Text("Motor de voz: \(crudo)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 8)
            Text(dictado.fecha, format: .dateTime.hour().minute())
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            BotonCopiar(texto: dictado.texto)
            Button {
                verCrudo.toggle()
            } label: {
                Image(systemName: verCrudo ? "waveform.circle.fill" : "waveform.circle")
            }
            .buttonStyle(.borderless)
            .help("Ver lo que dio el motor de voz")
            Button(action: borrar) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Borrar del historial")
        }
        .padding(.vertical, 6)
    }
}
