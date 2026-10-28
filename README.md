# Oxidos OS · Dictado por voz para Mac

Mantén pulsada una tecla, habla y suelta: lo que dices aparece escrito donde tengas el cursor, en cualquier app del Mac.
En español, y sin mandar tu voz a ningún servidor: todo pasa dentro del Mac, con el motor de voz de macOS.

Mientras hablas, una bola en 3D se mueve con tu voz.

## Qué hace

- **Dictar en cualquier app** con Fn o con el atajo que elijas.
- **El texto cae palabra a palabra**, muy rápido, sin pasar por el portapapeles.
- **Estilos de escritura** por tipo de app: Formal, Casual, Muy casual o Entusiasta, para mensajes personales, de
  trabajo, correo y lo demás.
- **Órdenes habladas**: «nueva línea» y «nuevo párrafo».
- **Espacio automático** si sigues escribiendo detrás de un texto.
- **Diccionario** con tus palabras y correcciones, que también ayudan al motor de voz a reconocerlas.
- **Historial y métricas**: palabras de hoy y de la semana, palabras por minuto, días seguidos y tiempo ahorrado.
- **La bola a tu gusto**: 31 estilos, entre ellos metales con colores medidos de verdad, piedras y gemas, con tamaño,
  luz, brillo y posición.
- **Ventana de cristal**, con el Liquid Glass de macOS 26.

## Qué necesitas

- Un Mac con Apple Silicon y **macOS 26** o posterior.
- Las **Command Line Tools** de Apple. No hace falta Xcode. Si no las tienes, en la Terminal: `xcode-select --install`.

## Cómo instalarla

```
git clone https://github.com/alejandro1234-99/dictado-por-voz-mac.git
cd dictado-por-voz-mac
scripts/crear-certificado.sh
scripts/fabricar-app.sh
```

1. `crear-certificado.sh` crea, una sola vez, un certificado propio para firmar la app. Pide la contraseña del Mac. Sirve
   para que macOS recuerde los permisos cuando instales versiones nuevas; sin él la app funciona igual, pero te los
   pedirá cada vez.
2. `fabricar-app.sh` compila la app, la firma, la instala en Aplicaciones como «Oxidos OS» y la abre. Tarda uno o dos
   minutos.

Al abrirla, en **Ajustes** concede el **micrófono** y la **Accesibilidad**. La Accesibilidad hace falta para escuchar la
tecla y escribir donde está el cursor. Si vas a dictar con Fn, en Ajustes del Sistema → Teclado pon «Pulsar la tecla 🌐
para» en «No hacer nada».

Si tienes otra app de dictado abierta con la misma tecla, ciérrala: si no, se escribirá todo dos veces.

## Cómo está hecha

- Swift y SwiftUI, en un paquete de Swift que se compila sin Xcode.
- La voz la transcribe `SpeechAnalyzer`, el motor de macOS 26, dentro del Mac.
- La tecla se escucha con un event tap de macOS, y el texto se escribe como pulsaciones de teclado.
- La bola se pinta punto a punto en el procesador, con luz de estudio. Los colores de los metales salen de la base de
  datos abierta [Physically Based](https://physicallybased.info).
- `Sources/DictadoNucleo` es la lógica sin interfaz y tiene sus pruebas: `swift test`, también en Linux.

## Licencia

MIT. Úsala, cámbiala y compártela.
