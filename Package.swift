// swift-tools-version: 6.2
import PackageDescription

var targets: [Target] = [
    // Lógica pura, sin dependencias del Mac: se puede probar sin micro ni pantalla, también en Linux.
    .target(name: "DictadoNucleo"),
    .testTarget(name: "DictadoNucleoTests", dependencies: ["DictadoNucleo"]),
]

// La app usa AppKit y el motor de voz de Apple: solo se compila en el Mac.
#if os(macOS)
targets.append(
    .executableTarget(
        name: "Dictado",
        dependencies: ["DictadoNucleo"],
        linkerSettings: [.linkedLibrary("sqlite3")]
    )
)
#else
// En Linux: pinta una hoja con todas las bolas para revisarlas sin Mac.
targets.append(.executableTarget(name: "MuestrasBola", dependencies: ["DictadoNucleo"]))
#endif

let package = Package(
    name: "Dictado",
    platforms: [.macOS("26.0")],
    targets: targets,
    swiftLanguageModes: [.v5]
)
