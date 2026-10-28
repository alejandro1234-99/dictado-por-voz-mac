#!/usr/bin/env python3
"""Hace el icono de Dictado: la bola, pintada con el código de la app, sobre la forma de los iconos de macOS.

Se lanza en Linux o en el Mac, con Swift para pintar la bola y Pillow para montar el icono:

    python3 scripts/hacer-icono.py [estilo]

Deja Recursos/Icono.icns y Recursos/icono-1024.png. El estilo, de serie, es la perla.
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageFilter

LADO = 1024
# Plantilla de iconos de macOS: la forma ocupa 824 de 1024, centrada, con esquinas de unos 185.
FORMA = 824
MARGEN = (LADO - FORMA) // 2
RADIO = 185
BOLA = 540
# Si Swift no está en el PATH, su carpeta bin en SWIFT_BIN.
SWIFT = os.environ.get("SWIFT_BIN", "")


def pintar_bola(estilo: str, carpeta: str) -> Image.Image:
    ruta = os.path.join(carpeta, "bola.rgba")
    entorno = dict(os.environ, PATH=(SWIFT + ":" if SWIFT else "") + os.environ.get("PATH", ""))
    subprocess.run(
        ["swift", "run", "-c", "release", "MuestrasBola", ruta, str(BOLA), "0.15", estilo],
        check=True, env=entorno, capture_output=True,
    )
    with open(ruta, "rb") as archivo:
        return Image.frombytes("RGBA", (BOLA, BOLA), archivo.read(), "raw", "RGBa")


def degradado(alto: int, arriba: tuple, abajo: tuple) -> Image.Image:
    capa = Image.new("RGBA", (1, alto))
    for y in range(alto):
        t = y / (alto - 1)
        capa.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(arriba, abajo)) + (255,))
    return capa.resize((FORMA, alto))


def mascara_forma() -> Image.Image:
    mascara = Image.new("L", (FORMA, FORMA), 0)
    ImageDraw.Draw(mascara).rounded_rectangle((0, 0, FORMA - 1, FORMA - 1), radius=RADIO, fill=255)
    return mascara


def hacer(estilo: str) -> Image.Image:
    with tempfile.TemporaryDirectory() as carpeta:
        bola = pintar_bola(estilo, carpeta)

    mascara = mascara_forma()
    # Grafito, como la tarjeta de portada: algo más claro arriba.
    fondo = degradado(FORMA, (52, 56, 64), (18, 20, 24))
    # Luz azul suave detrás de la bola.
    luz = Image.new("RGBA", (FORMA, FORMA), (0, 0, 0, 0))
    ImageDraw.Draw(luz).ellipse((150, 120, FORMA - 150, FORMA - 180), fill=(80, 130, 240, 90))
    fondo = Image.alpha_composite(fondo, luz.filter(ImageFilter.GaussianBlur(90)))
    # Filo de luz arriba: el relieve de los iconos de Apple.
    filo = Image.new("RGBA", (FORMA, FORMA), (0, 0, 0, 0))
    ImageDraw.Draw(filo).rounded_rectangle((2, 2, FORMA - 3, FORMA - 3), radius=RADIO - 2, outline=(255, 255, 255, 46), width=3)
    filo.putalpha(ImageChops.multiply(filo.getchannel("A"), degradado(FORMA, (255, 255, 255), (0, 0, 0)).getchannel("R")))
    fondo = Image.alpha_composite(fondo, filo)

    # Sombra de la bola sobre el fondo y la bola, algo por encima del centro.
    x = (FORMA - BOLA) // 2
    y = (FORMA - BOLA) // 2 - 18
    sombra = Image.new("RGBA", (FORMA, FORMA), (0, 0, 0, 0))
    ImageDraw.Draw(sombra).ellipse((x + 40, y + BOLA - 10, x + BOLA - 40, y + BOLA + 70), fill=(0, 0, 0, 150))
    fondo = Image.alpha_composite(fondo, sombra.filter(ImageFilter.GaussianBlur(28)))
    fondo.alpha_composite(bola, (x, y))
    fondo.putalpha(ImageChops.multiply(fondo.getchannel("A"), mascara))

    # La forma lleva su sombra debajo, como todos los iconos de macOS.
    icono = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    sombra_forma = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    sombra_forma.paste((0, 0, 0, 110), (MARGEN, MARGEN + 12), mascara)
    icono = Image.alpha_composite(icono, sombra_forma.filter(ImageFilter.GaussianBlur(14)))
    icono.alpha_composite(fondo, (MARGEN, MARGEN))
    return icono


def main() -> None:
    estilo = sys.argv[1] if len(sys.argv) > 1 else "perla"
    raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(raiz)
    icono = hacer(estilo)
    icono.save(os.path.join("Recursos", "icono-1024.png"))
    tamanos = [(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)]
    icono.save(os.path.join("Recursos", "Icono.icns"), sizes=tamanos)
    print("Recursos/Icono.icns y Recursos/icono-1024.png")


if __name__ == "__main__":
    main()
