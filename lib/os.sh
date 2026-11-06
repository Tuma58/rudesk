#!/usr/bin/env bash
# shellcheck shell=bash

detect_os() {
  [[ -f /etc/os-release ]] || die "Не найден /etc/os-release — поддерживаются только Debian/Ubuntu."
  # shellcheck disable=SC1091
  . /etc/os-release

  local id="${ID:-}"
  local like="${ID_LIKE:-}"

  case "${id}" in
    debian|ubuntu) ;;
    *)
      if [[ " ${like} " != *" debian "* && " ${like} " != *" ubuntu "* ]]; then
        die "Поддерживаются только Debian и Ubuntu (сейчас: ${PRETTY_NAME:-unknown})."
      fi
      ;;
  esac

  command -v systemctl >/dev/null 2>&1 || die "Нужен systemd (systemctl). На минимальных контейнерах без systemd rudesk не ставится."
  command -v apt-get >/dev/null 2>&1 || die "Не найден apt-get."

  RUDESK_OS_ID="${id}"
  RUDESK_OS_VERSION="${VERSION_ID:-}"
  RUDESK_OS_NAME="${PRETTY_NAME:-$id}"
  ok "ОС: ${RUDESK_OS_NAME}"
}

detect_arch() {
  local machine
  machine="$(uname -m)"
  case "${machine}" in
    x86_64|amd64) RUDESK_ARCH="amd64" ;;
    aarch64|arm64) RUDESK_ARCH="arm64" ;;
    *) die "Неподдерживаемая архитектура: ${machine} (нужны amd64 или arm64)." ;;
  esac
  ok "Архитектура: ${RUDESK_ARCH}"
}

# Пакеты, без которых install.sh и сервисы не работают на «голом» VPS.
rudesk_base_packages() {
  local pkgs=(
    ca-certificates
    curl
    wget
    tar
    gzip
    coreutils
    findutils
    grep
    sed
    gawk
    procps
    iproute2
    openssl
  )

  # dig для автоопределения WAN IP (имя пакета отличается)
  if apt-cache show bind9-dnsutils >/dev/null 2>&1; then
    pkgs+=(bind9-dnsutils)
  elif apt-cache show dnsutils >/dev/null 2>&1; then
    pkgs+=(dnsutils)
  fi

  if [[ "${RUDESK_SETUP_UFW:-0}" == "1" ]]; then
    pkgs+=(ufw)
  fi

  printf '%s\n' "${pkgs[@]}"
}

apt_retry() {
  local attempt
  for attempt in 1 2 3 4 5; do
    if "$@"; then
      return 0
    fi
    warn "Команда apt не удалась (попытка ${attempt}/5). Ждём 10 с — часто это unattended-upgrades на новом VPS."
    sleep 10
  done
  die "Не удалось выполнить: $*"
}

install_base_apt() {
  export DEBIAN_FRONTEND=noninteractive

  log "Обновление индексов apt и установка зависимостей для чистого VPS..."
  apt_retry apt-get update -y

  # UFW ещё не выбран — ставим обязательный минимум до wizard
  local pkgs=()
  mapfile -t pkgs < <(RUDESK_SETUP_UFW=0 rudesk_base_packages)
  apt_retry apt-get install -y "${pkgs[@]}"

  local need
  for need in curl tar gzip sha256sum systemctl; do
    command -v "${need}" >/dev/null 2>&1 || die "После установки пакетов не найдена команда: ${need}"
  done

  ok "Системные зависимости установлены"
}

install_ufw_apt() {
  [[ "${RUDESK_SETUP_UFW:-0}" == "1" ]] || return 0
  export DEBIAN_FRONTEND=noninteractive

  if rudesk_ufw_bin >/dev/null 2>&1; then
    ok "ufw уже установлен: $(rudesk_ufw_bin)"
    return 0
  fi

  log "Установка ufw..."
  apt_retry apt-get install -y ufw
  rudesk_ufw_bin >/dev/null 2>&1 || die "Пакет ufw установлен, но бинарник не найден (проверьте /usr/sbin/ufw и PATH)."
  ok "ufw готов: $(rudesk_ufw_bin)"
}
