#!/usr/bin/env bash
# Creates a self-signed "Pico Dev" code-signing certificate in your login keychain.
#
# Why: an ad-hoc signature changes on every rebuild, so macOS forgets the Accessibility grant and
# asks for the keychain password each time. Signing with one stable local identity fixes both.
# build-app.sh picks the certificate up automatically when it exists. Local development only; the
# public DMG is built by GitHub Actions.
#
# macOS will ask for your login password once or twice (to import the certificate and trust it).
set -euo pipefail

NAME="Pico Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "$NAME"; then
  echo "'$NAME' already exists."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/ext.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/ext.cnf" 2>/dev/null
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/cert.p12" -passout pass:pico

security import "$TMP/cert.p12" -k "$KEYCHAIN" -P pico -T /usr/bin/codesign -T /usr/bin/security
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

echo "Created '$NAME'. Rebuild with scripts/build-app.sh; the app is now signed with it."
