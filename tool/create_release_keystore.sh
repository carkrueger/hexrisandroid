#!/usr/bin/env bash
# Creates the Hexris release signing key and stores it as the GitHub secrets
# that .github/workflows/release.yml signs releases with. Run it once, on your
# own machine, and back up the keystore: without it no installed copy of the
# app can ever be updated again.
#
# Usage:
#   tool/create_release_keystore.sh [KEYSTORE]   (default: ~/hexris-release.jks)
#
# Needs keytool (any JDK 11+), openssl, and for storing the secrets the GitHub
# CLI (gh), logged in with access to the repository. Set
# HEXRIS_KEYSTORE_PASSWORD to skip the password prompt.
set -euo pipefail

KEYSTORE="${1:-$HOME/hexris-release.jks}"
ALIAS=hexris

for tool in keytool openssl; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: $tool not found" >&2; exit 1; }
done

if [ -e "$KEYSTORE" ]; then
  echo "error: $KEYSTORE already exists; not overwriting a signing key." >&2
  echo "To store an existing keystore as secrets, see docs/android-release.md." >&2
  exit 1
fi

case "$(cd "$(dirname "$KEYSTORE")" && pwd)/" in
  "$(git rev-parse --show-toplevel 2>/dev/null || echo /nonexistent)"/*)
    echo "error: keep the keystore outside the repository." >&2
    exit 1
    ;;
esac

password="${HEXRIS_KEYSTORE_PASSWORD:-}"
if [ -z "$password" ]; then
  read -rsp "Password for the new keystore (at least 12 characters): " password
  echo
  read -rsp "Repeat the password: " again
  echo
  [ "$password" = "$again" ] || { echo "error: passwords differ" >&2; exit 1; }
fi
[ "${#password}" -ge 12 ] || { echo "error: password too short" >&2; exit 1; }

# PKCS12 keystores use the keystore password for the key as well.
keytool -genkeypair -keystore "$KEYSTORE" -storetype PKCS12 -alias "$ALIAS" \
  -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Hexris" \
  -storepass "$password" -keypass "$password" >/dev/null
chmod 600 "$KEYSTORE"

fingerprint=$(keytool -list -v -keystore "$KEYSTORE" -storepass "$password" -alias "$ALIAS" \
  | sed -n 's/^[[:space:]]*SHA256: //p')

cat <<EOF

Created $KEYSTORE (alias $ALIAS).
Certificate SHA-256: $fingerprint

Back up this file and its password now (e.g. in a password manager). If it
is lost, installed copies of Hexris can never be updated again.

EOF

repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [ -z "$repo" ]; then
  cat <<EOF
gh is not available or not logged in here. Add these repository secrets by
hand (GitHub > Settings > Secrets and variables > Actions):

  HEXRIS_KEYSTORE_BASE64    output of: openssl base64 -A -in "$KEYSTORE"
  HEXRIS_KEYSTORE_PASSWORD  the password
  HEXRIS_KEY_ALIAS          $ALIAS
  HEXRIS_KEY_PASSWORD       the password
EOF
  exit 0
fi

read -rp "Store the key as GitHub Actions secrets of $repo? [y/N] " answer
case "$answer" in
  y | Y | yes) ;;
  *) echo "Not stored. See docs/android-release.md for the secret names."; exit 0 ;;
esac

# Values go through stdin, not the command line, so they don't show up in
# the process list.
openssl base64 -A -in "$KEYSTORE" | gh secret set HEXRIS_KEYSTORE_BASE64 --repo "$repo"
printf '%s' "$password" | gh secret set HEXRIS_KEYSTORE_PASSWORD --repo "$repo"
printf '%s' "$ALIAS" | gh secret set HEXRIS_KEY_ALIAS --repo "$repo"
printf '%s' "$password" | gh secret set HEXRIS_KEY_PASSWORD --repo "$repo"

echo
echo "Secrets stored. The next push to main builds, signs and publishes the release."
