import DictadoNucleo
import Foundation

// Pinta bolas en una hoja RGBA sin cabecera, con la opacidad multiplicada, para revisarlas o hacer el icono.
// Uso: MuestrasBola <archivo de salida> [lado] [energía] [estilo]
// Sin estilo pinta todas en una hoja de 5 columnas; con estilo, solo esa, del lado pedido.
let argumentos = CommandLine.arguments
guard argumentos.count >= 2 else {
    print("Uso: MuestrasBola <archivo de salida> [lado] [energía] [estilo]")
    exit(1)
}
let lado = argumentos.count > 2 ? Int(argumentos[2]) ?? 160 : 160
let energia = argumentos.count > 3 ? Double(argumentos[3]) ?? 0.3 : 0.3
let pintor = PintorBola(lado: lado)

if argumentos.count > 4 {
    guard let estilo = EstiloBola(rawValue: argumentos[4]) else {
        print("Estilo desconocido: \(argumentos[4])")
        exit(1)
    }
    pintor.pintar(estilo: estilo, fase: 1.3, energia: energia)
    FileManager.default.createFile(atPath: argumentos[1], contents: Data(pintor.pixeles))
    print("\(lado)x\(lado) \(estilo.nombre)")
    exit(0)
}

let bolas = EstiloBola.allCases.filter { !$0.esCapsula }
let columnas = 5
let filas = (bolas.count + columnas - 1) / columnas
let ancho = columnas * lado
var hoja = [UInt8](repeating: 0, count: ancho * filas * lado * 4)

for (indice, estilo) in bolas.enumerated() {
    pintor.pintar(estilo: estilo, fase: 1.3, energia: energia)
    let x0 = (indice % columnas) * lado
    let y0 = (indice / columnas) * lado
    for j in 0..<lado {
        let desde = j * lado * 4
        let hacia = ((y0 + j) * ancho + x0) * 4
        hoja.replaceSubrange(hacia..<(hacia + lado * 4), with: pintor.pixeles[desde..<(desde + lado * 4)])
    }
}
FileManager.default.createFile(atPath: argumentos[1], contents: Data(hoja))
print("\(ancho)x\(filas * lado) \(bolas.map(\.nombre).joined(separator: ","))")
