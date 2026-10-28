import AppKit
import DictadoNucleo
import SwiftUI

/// Inicio: la bola, las palabras de hoy, las cifras, la semana y los últimos dictados.
struct VistaInicio: View {
    @ObservedObject var estado: EstadoApp
    @ObservedObject var datos: DatosApp
    /// Sube al cerrar la otra app de dictado, para volver a mirar si sigue abierta.
    @State private var revisar = 0

    init(estado: EstadoApp, datos: DatosApp) {
        self.estado = estado
        self.datos = datos
    }

    var body: some View {
        let m = datos.metricas
        let _ = revisar
        VStack(alignment: .leading, spacing: 14) {
            TituloSeccion(Self.saludo())

            if estado.faltanPermisos {
                aviso(
                    "Faltan permisos para dictar.",
                    boton: "Abrir Ajustes"
                ) { estado.seccion = .ajustes }
            }
            if let otra = OtraAppDeDictado.abierta() {
                aviso("\(otra) también está abierta y puede escribir todo dos veces.", boton: "Cerrar \(otra)") {
                    OtraAppDeDictado.cerrar()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { revisar += 1 }
                }
            }

            portada(m)
            cifras(m)
            HStack(alignment: .top, spacing: 14) {
                grafico(m)
                ultimos
            }
        }
    }

    // MARK: - Piezas

    private func portada(_ m: Metricas) -> some View {
        HStack(spacing: 26) {
            BolaAnimada(apariencia: estado.bola, diametro: 132)
                .shadow(color: Color.black.opacity(0.45), radius: 14, y: 12)
            VStack(alignment: .leading, spacing: 6) {
                Text(Metricas.cifra(m.hoy))
                    .font(.system(size: 60, weight: .semibold))
                    .tracking(-1.6)
                    .monospacedDigit()
                Text("palabras hoy")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.62))
                HStack(spacing: 8) {
                    Etiqueta(texto: "\(m.palabrasPorMinuto) palabras por minuto", claro: true)
                    Etiqueta(texto: m.dictadosHoy == 1 ? "1 dictado" : "\(m.dictadosHoy) dictados", claro: true)
                }
                .padding(.top, 8)
            }
            .foregroundStyle(Color.white)
            Spacer(minLength: 0)
        }
        .cristal(radio: 22, relleno: 26, oscuro: true)
    }

    private func cifras(_ m: Metricas) -> some View {
        HStack(spacing: 14) {
            cifra("Esta semana", Metricas.cifra(m.semana))
            cifra("En total", Metricas.cifra(m.total))
            cifra("Días seguidos", "\(m.diasSeguidos)")
            cifra("Tiempo ahorrado", Metricas.tiempo(m.segundosAhorrados))
        }
    }

    private func cifra(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
            Text(valor)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .cristal()
    }

    private func grafico(_ m: Metricas) -> some View {
        let maximo = max(1, m.ultimos7Dias.map(\.palabras).max() ?? 1)
        return VStack(alignment: .leading, spacing: 14) {
            Text("Últimos 7 días")
                .font(.system(size: 13, weight: .semibold))
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(m.ultimos7Dias.enumerated()), id: \.offset) { indice, dia in
                    let hoy = indice == m.ultimos7Dias.count - 1
                    VStack(spacing: 6) {
                        Text(Metricas.cifra(dia.palabras))
                            .font(.system(size: 11, weight: hoy ? .semibold : .regular))
                            .foregroundStyle(hoy ? Color.primary : Color.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(hoy ? Color.acento : Color.primary.opacity(0.1))
                            .frame(maxWidth: 30)
                            .frame(height: max(4, 110 * CGFloat(dia.palabras) / CGFloat(maximo)))
                        Text(Self.inicial(dia.dia))
                            .font(.system(size: 11, weight: hoy ? .semibold : .regular))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150, alignment: .bottom)
        }
        .cristal()
    }

    private var ultimos: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Últimos dictados")
                .font(.system(size: 13, weight: .semibold))
                .padding(.bottom, 4)
            if datos.ultimos.isEmpty {
                Text("Mantén \(estado.atajo.nombre) y habla: aquí saldrán tus dictados.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
            ForEach(Array(datos.ultimos.enumerated()), id: \.element.id) { indice, dictado in
                if indice > 0 {
                    Divider().opacity(0.5)
                }
                FilaDictado(dictado: dictado)
            }
        }
        .cristal()
    }

    private func aviso(_ texto: String, boton: String, accion: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            Text(texto)
            Spacer()
            Button(boton, action: accion)
                .buttonStyle(.glassProminent)
        }
        .cristal(relleno: 14)
    }

    // MARK: - Textos

    private static func saludo() -> String {
        let hora = Calendar.current.component(.hour, from: Date())
        let parte = hora < 14 ? "Buenos días" : hora < 21 ? "Buenas tardes" : "Buenas noches"
        let nombre = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        return nombre.isEmpty ? parte : "\(parte), \(nombre)"
    }

    /// L, M, X, J, V, S y D, como en los calendarios de España.
    private static func inicial(_ dia: Date) -> String {
        let letras = ["D", "L", "M", "X", "J", "V", "S"]
        return letras[(Calendar.current.component(.weekday, from: dia) - 1) % 7]
    }
}

/// Una fila de dictado: la app donde se dictó, el texto, la hora y copiar.
struct FilaDictado: View {
    let dictado: DictadoGuardado

    var body: some View {
        HStack(spacing: 12) {
            IconoApp(bundle: dictado.appBundle, nombre: dictado.app)
            Text(dictado.texto)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(dictado.fecha, format: .dateTime.hour().minute())
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            BotonCopiar(texto: dictado.texto)
        }
        .padding(.vertical, 6)
    }
}

/// «Copiar», que dice «Copiado» un momento al pulsarlo.
struct BotonCopiar: View {
    let texto: String
    @State private var copiado = false

    init(texto: String) {
        self.texto = texto
    }

    var body: some View {
        Button(copiado ? "Copiado" : "Copiar") {
            DatosApp.copiar(texto)
            copiado = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiado = false }
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12))
    }
}

/// Otras apps de dictado que escuchan la misma tecla: con dos a la vez, el texto sale dos veces.
enum OtraAppDeDictado {
    private static func buscar() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            let nombre = (app.localizedName ?? "").lowercased()
            let identificador = (app.bundleIdentifier ?? "").lowercased()
            return nombre.contains("wispr") || identificador.contains("wispr")
        }
    }

    static func abierta() -> String? {
        guard let app = buscar() else { return nil }
        return app.localizedName ?? "Wispr Flow"
    }

    static func cerrar() {
        buscar()?.terminate()
    }
}
