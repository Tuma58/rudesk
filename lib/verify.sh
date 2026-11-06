#!/usr/bin/env bash
# shellcheck shell=bash

verify_vendor() {
  local vendor_dir="${RUDESK_ROOT}/vendor/rustdesk-server"
  local sums="${vendor_dir}/SHA256SUMS"
  local arch_dir="${vendor_dir}/${RUDESK_ARCH}"

  [[ -d "${vendor_dir}" ]] || die "Нет каталога vendor/rustdesk-server в репозитории."
  [[ -f "${sums}" ]] || die "Нет ${sums}"
  [[ -x "${arch_dir}/hbbs" && -x "${arch_dir}/hbbr" ]] || die "Нет бинарников в ${arch_dir}"

  log "Проверка SHA256 вендорных бинарников (${RUDESK_ARCH})..."
  (
    cd "${vendor_dir}"
    # Проверяем только файлы текущей архитектуры
    grep -E "^[0-9a-f]{64}  ${RUDESK_ARCH}/" SHA256SUMS | sha256sum -c -
  )
  ok "Контрольные суммы совпали (версия $(tr -d '\n' < "${vendor_dir}/VERSION"))"
}
