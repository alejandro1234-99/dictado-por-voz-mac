import SwiftUI

@main
struct DictadoApp: App {
    @NSApplicationDelegateAdaptor(Delegado.self) private var delegado
    @StateObject private var estado = EstadoApp.compartido

    var body: some Scene {
        MenuBarExtra {
            if !estado.microConcedido {
                Button("Falta el permiso del micrófono…") { Permisos.abrir(.micro) }
            }
            if !estado.accesibilidadConcedida {
                Button("Falta el permiso de Accesibilidad…") { Permisos.pedirAccesibilidad() }
            }
            if estado.faltanPermisos {
                Divider()
            }
            Button("Abrir Oxidos OS") { delegado.mostrarVentana() }
            Divider()
            Button("Salir") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: estado.iconoMenu)
        }
        // La barra de menús de arriba, como en cualquier app: Acerca de, Ajustes con ⌘, y Salir con ⌘Q.
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Ajustes…") { delegado.mostrarVentana(en: .ajustes) }
                    .keyboardShortcut(",")
            }
        }
    }
}
