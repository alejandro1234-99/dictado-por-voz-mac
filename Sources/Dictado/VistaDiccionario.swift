import DictadoNucleo
import SwiftUI

/// Diccionario: palabras propias, que el motor de voz tiene en cuenta, y correcciones «si oyes X, escribe Y».
struct VistaDiccionario: View {
    @ObservedObject var datos: DatosApp
    @State private var palabra = ""
    @State private var seOye = ""

    init(datos: DatosApp) {
        self.datos = datos
    }

    var body: some View {
        let propias = datos.diccionario.filter { !$0.esCorreccion }
        let correcciones = datos.diccionario.filter(\.esCorreccion)
        VStack(alignment: .leading, spacing: 14) {
            TituloSeccion("Diccionario")

            HStack(spacing: 10) {
                TextField("Cómo se escribe, por ejemplo GitHub", text: $palabra)
                    .textFieldStyle(.roundedBorder)
                TextField("Cómo lo oye, si lo escribe mal", text: $seOye)
                    .textFieldStyle(.roundedBorder)
                Button("Añadir", action: anadir)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(palabra.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .cristal(relleno: 14)

            VStack(alignment: .leading, spacing: 12) {
                Text("Palabras")
                    .font(.system(size: 13, weight: .semibold))
                if propias.isEmpty {
                    Text("Nombres, marcas y términos técnicos que quieras que escriba bien.")
                        .foregroundStyle(.secondary)
                }
                Fluir {
                    ForEach(propias) { entrada in
                        EtiquetaBorrable(texto: entrada.palabra) { datos.borrar(entrada) }
                    }
                }
            }
            .cristal()

            VStack(alignment: .leading, spacing: 4) {
                Text("Correcciones")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.bottom, 4)
                if correcciones.isEmpty {
                    Text("Si entiende mal algo siempre igual, añádelo con cómo lo oye y lo corregirá solo.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(correcciones.enumerated()), id: \.element.id) { indice, entrada in
                    if indice > 0 {
                        Divider().opacity(0.5)
                    }
                    HStack(spacing: 10) {
                        Text(entrada.seOye ?? "")
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.tertiary)
                        Text(entrada.palabra)
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            datos.borrar(entrada)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Borrar la corrección")
                    }
                    .padding(.vertical, 6)
                }
            }
            .cristal()
        }
    }

    private func anadir() {
        datos.anadir(palabra: palabra, seOye: seOye)
        palabra = ""
        seOye = ""
    }
}

/// Una palabra del diccionario, en píldora de cristal, con su aspa para borrarla.
private struct EtiquetaBorrable: View {
    let texto: String
    let borrar: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(texto)
                .font(.system(size: 13, weight: .medium))
            Button(action: borrar) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Borrar «\(texto)»")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}
