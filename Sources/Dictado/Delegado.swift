import AppKit

final class Delegado: NSObject, NSApplicationDelegate {
    private let estado = EstadoApp.compartido
    private let ventana = VentanaPrincipal()
    private let coordinador = Coordinador()
    private var reloj: Timer?

    /// Una sola copia de Dictado: si hay otra abierta, por ejemplo de una versión anterior, se cierra. Dos copias
    /// escucharían el atajo a la vez y escribirían todo dos veces.
    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let identificador = Bundle.main.bundleIdentifier else { return }
        let yo = ProcessInfo.processInfo.processIdentifier
        for otra in NSRunningApplication.runningApplications(withBundleIdentifier: identificador)
        where otra.processIdentifier != yo {
            otra.forceTerminate()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App de verdad: icono y punto en el Dock, en el selector de apps y con su barra de menús.
        NSApp.setActivationPolicy(.regular)
        // Mirarlo ahora: el evento de apertura solo se puede leer mientras se atiende.
        let abiertaAlIniciarSesion = Self.abiertaAlIniciarSesion()

        // El motor de voz baja el español la primera vez; así el primer dictado no espera.
        Task {
            do {
                try await TranscriptorApple.prepararIdioma()
            } catch {
                NSLog("Dictado: no se pudo preparar el español del motor de voz: \(error.localizedDescription)")
            }
        }
        refrescarPermisos()

        // Los permisos se conceden en Ajustes del Sistema: se revisan cada segundo.
        reloj = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refrescarPermisos()
        }

        // Si se quería abrir al iniciar sesión y macOS lo ha olvidado, por ejemplo al cambiar el nombre de
        // la app, se vuelve a apuntar.
        if Ajustes.abrirAlIniciarDeseado && !AlIniciar.activado {
            estado.abrirAlIniciar = true
        }
        // Abierta a mano, enseña su ventana; al iniciar sesión se queda en el Dock sin molestar, salvo que falte algo.
        // La primera vez, o si falta un permiso, abre en Ajustes, que es donde se conceden.
        if !abiertaAlIniciarSesion || !Ajustes.bienvenidaVista || estado.faltanPermisos {
            mostrarVentana(en: estado.faltanPermisos ? Seccion.ajustes : nil)
        }
        Ajustes.bienvenidaVista = true
    }

    /// Hacer clic en el Dock, o abrirla desde Spotlight o Aplicaciones cuando ya está en marcha, trae su ventana.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mostrarVentana()
        return true
    }

    /// Cerrar la ventana no cierra la app: sigue escuchando el atajo. Para cerrarla del todo, Salir o ⌘Q.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// El clic derecho en el Dock: macOS pone Opciones (mantener en el Dock, abrir al iniciar sesión) y Salir.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let abrir = NSMenuItem(title: "Abrir Oxidos OS", action: #selector(abrirDesdeElDock), keyEquivalent: "")
        abrir.target = self
        menu.addItem(abrir)
        return menu
    }

    @objc private func abrirDesdeElDock() {
        mostrarVentana()
    }

    /// macOS marca la apertura al iniciar sesión en el evento de abrir la app. Los códigos van escritos a mano:
    /// 'oapp' es abrir la app, 'prdt' el dato que acompaña y 'lgit' que se abrió al iniciar sesión.
    private static func abiertaAlIniciarSesion() -> Bool {
        let abrirApp: AEEventID = 0x6F61_7070
        let dato: AEKeyword = 0x7072_6474
        let alIniciarSesion: OSType = 0x6C67_6974
        guard let evento = NSAppleEventManager.shared().currentAppleEvent, evento.eventID == abrirApp else {
            return false
        }
        return evento.paramDescriptor(forKeyword: dato)?.enumCodeValue == alIniciarSesion
    }

    func mostrarVentana(en seccion: Seccion? = nil) {
        ventana.mostrar(estado: estado, en: seccion)
    }

    private func refrescarPermisos() {
        let micro = Permisos.micro
        let accesibilidad = Permisos.accesibilidad
        if estado.microConcedido != micro { estado.microConcedido = micro }
        if estado.accesibilidadConcedida != accesibilidad { estado.accesibilidadConcedida = accesibilidad }
        coordinador.arrancarSiSePuede()
    }
}
