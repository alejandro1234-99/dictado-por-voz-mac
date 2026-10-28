#!/bin/bash
# Crea, una sola vez, el certificado propio «Oxidos Desarrollo» para firmar las apps de Oxidos OS.
# Con él, macOS recuerda los permisos (micro, Accesibilidad) aunque se instale una versión nueva.
# Se lanza en el Mac. Al final macOS pide la contraseña del Mac para marcarlo de confianza.
set -euo pipefail

NOMBRE="Oxidos Desarrollo"
LLAVERO="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "$NOMBRE"; then
  echo "El certificado «${NOMBRE}» ya está creado."
  exit 0
fi

TEMPORAL=$(mktemp -d)
trap 'rm -rf "$TEMPORAL"' EXIT

cat > "$TEMPORAL/certificado.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $NOMBRE
[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# /usr/bin/openssl es el LibreSSL de macOS: su .p12 lo entiende el llavero sin opciones extra.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TEMPORAL/clave.pem" -out "$TEMPORAL/certificado.pem" -config "$TEMPORAL/certificado.cnf" 2>/dev/null
CLAVE_P12=$(/usr/bin/openssl rand -hex 12)
/usr/bin/openssl pkcs12 -export -inkey "$TEMPORAL/clave.pem" -in "$TEMPORAL/certificado.pem" \
  -name "$NOMBRE" -out "$TEMPORAL/certificado.p12" -passout "pass:$CLAVE_P12"

security import "$TEMPORAL/certificado.p12" -k "$LLAVERO" -P "$CLAVE_P12" -T /usr/bin/codesign >/dev/null
echo "Ahora macOS te pedirá la contraseña del Mac para confiar en el certificado."
security add-trusted-cert -r trustRoot -p codeSign -k "$LLAVERO" "$TEMPORAL/certificado.pem"

if security find-identity -v -p codesigning | grep -q "$NOMBRE"; then
  echo "✅ Certificado «${NOMBRE}» creado."
else
  echo "❌ El certificado se importó pero macOS no lo da por válido para firmar."
  exit 1
fi
