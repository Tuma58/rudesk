#!/usr/bin/env bash
# Мейнтейнерский скрипт: обновить vendor/ с выбранного upstream-релиза.
# Запускается на машине разработчика. Пользовательский install.sh этот скрипт не вызывает.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
[[ -n "${VERSION}" ]] || {
  echo "Usage: $0 <version>   # например: $0 1.1.16" >&2
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

BASE="https://github.com/rustdesk/rustdesk-server/releases/download/${VERSION}"
mkdir -p "${ROOT}/vendor/rustdesk-server/amd64" "${ROOT}/vendor/rustdesk-server/arm64"

curl -fsSL -L -o "${TMP}/amd64.zip" "${BASE}/rustdesk-server-linux-amd64.zip"
curl -fsSL -L -o "${TMP}/arm64.zip" "${BASE}/rustdesk-server-linux-arm64v8.zip"
curl -fsSL -L -o "${ROOT}/vendor/rustdesk-server/LICENSE" \
  "https://raw.githubusercontent.com/rustdesk/rustdesk-server/${VERSION}/LICENSE" \
  || curl -fsSL -L -o "${ROOT}/vendor/rustdesk-server/LICENSE" \
  "https://raw.githubusercontent.com/rustdesk/rustdesk-server/master/LICENSE"

unzip -qo "${TMP}/amd64.zip" -d "${TMP}/amd64"
unzip -qo "${TMP}/arm64.zip" -d "${TMP}/arm64"

install -m 0755 "${TMP}/amd64/amd64/hbbs" "${ROOT}/vendor/rustdesk-server/amd64/hbbs"
install -m 0755 "${TMP}/amd64/amd64/hbbr" "${ROOT}/vendor/rustdesk-server/amd64/hbbr"
install -m 0755 "${TMP}/arm64/arm64v8/hbbs" "${ROOT}/vendor/rustdesk-server/arm64/hbbs"
install -m 0755 "${TMP}/arm64/arm64v8/hbbr" "${ROOT}/vendor/rustdesk-server/arm64/hbbr"

printf '%s\n' "${VERSION}" > "${ROOT}/vendor/rustdesk-server/VERSION"
cat > "${ROOT}/vendor/rustdesk-server/SOURCE.txt" <<EOF
Vendored from RustDesk Server OSS release ${VERSION}
Upstream project: https://github.com/rustdesk/rustdesk-server
Files: hbbs, hbbr (linux amd64 and arm64)
Downloaded once into this repository so installs do not fetch upstream at runtime.
EOF

(
  cd "${ROOT}/vendor/rustdesk-server"
  shasum -a 256 amd64/hbbs amd64/hbbr arm64/hbbs arm64/hbbr > SHA256SUMS
)

echo "Vendor updated to ${VERSION}"
cat "${ROOT}/vendor/rustdesk-server/SHA256SUMS"
