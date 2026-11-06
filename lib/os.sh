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

install_base_apt() {
  log "Установка базовых пакетов через apt (ca-certificates curl)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y ca-certificates curl
}

install_ufw_apt() {
  [[ "${RUDESK_SETUP_UFW:-0}" == "1" ]] || return 0
  log "Установка ufw через apt..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y ufw
}
