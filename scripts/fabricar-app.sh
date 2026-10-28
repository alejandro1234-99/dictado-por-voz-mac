#!/bin/bash
# Compila Oxidos OS, monta «Oxidos OS.app», lo firma y lo instala en Aplicaciones. Se lanza en el Mac.
# Por dentro el programa sigue llamándose Dictado y conserva su identificador: así macOS mantiene los permisos.
set -euo pipefail
cd "$(dirname "$0")/.."

INICIO=$(date +%s)
IDENTIDAD="Oxidos Desarrollo"
NOMBRE="Oxidos OS"
APP=".build/${NOMBRE}.app"
INSTALADA="/Applications/${NOMBRE}.app"
# Las primeras versiones se instalaban como Dictado: esa copia se quita para que no queden dos.
ANTIGUA="/Applications/Dictado.app"

echo "Compilando…"
swift build -c release
BINARIO="$(swift build -c release --show-bin-path)/Dictado"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARIO" "$APP/Contents/MacOS/Dictado"
cp Recursos/Info.plist "$APP/Contents/Info.plist"
cp Recursos/Icono.icns "$APP/Contents/Resources/Icono.icns"

if security find-identity -v -p codesigning | grep -q "$IDENTIDAD"; then
  codesign --force --sign "$IDENTIDAD" "$APP"
else
  echo "⚠️  Falta el certificado «${IDENTIDAD}»: firmo sin él y macOS pedirá los permisos en cada versión."
  echo "    Para crearlo: scripts/crear-certificado.sh"
  codesign --force --sign - "$APP"
fi

# Cierra todas las copias abiertas, si las hay, y espera a que acaben: dos a la vez escribirían todo dos veces.
pkill -x Dictado || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x Dictado >/dev/null || break
  sleep 0.5
done
pkill -9 -x Dictado || true
rm -rf "$ANTIGUA"
rm -rf "$INSTALADA"
cp -R "$APP" /Applications/
# Que el Dock y el Finder vean el icono nuevo sin esperar.
touch "$INSTALADA"
open "$INSTALADA"

echo "✅ ${NOMBRE} instalado y abierto en $(( $(date +%s) - INICIO )) s."
