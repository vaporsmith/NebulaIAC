#!/usr/bin/env bash

set -euo pipefail

AGE_DIRECTORY="${NEBULAIAC_AGE_DIR:-/data/.age}"
AGE_IDENTITY_FILE="${AGE_DIRECTORY}/keys.txt"

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  TARGET_USER="${SUDO_USER}"
else
  TARGET_USER="$(id -un)"
fi

TARGET_UID="$(id -u "${TARGET_USER}")"
TARGET_GID="$(id -g "${TARGET_USER}")"

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

run_privileged() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo -- "$@"
  else
    fail "creating ${AGE_DIRECTORY} requires root privileges, but sudo is unavailable"
  fi
}

run_as_target() {
  if [[ "$(id -u)" -eq "${TARGET_UID}" ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo -u "${TARGET_USER}" -- "$@"
  else
    fail "cannot run age-keygen as ${TARGET_USER}; sudo is unavailable"
  fi
}

command -v age-keygen >/dev/null 2>&1 || fail \
  "age-keygen is not installed; on Pop!_OS or Ubuntu run: sudo apt install age"

[[ "${AGE_DIRECTORY}" = /* ]] || fail "NEBULAIAC_AGE_DIR must be an absolute path"
[[ ! -L "${AGE_DIRECTORY}" ]] || fail "refusing to use symlinked directory: ${AGE_DIRECTORY}"

run_privileged install -d \
  -o "${TARGET_UID}" \
  -g "${TARGET_GID}" \
  -m 0700 \
  "${AGE_DIRECTORY}"

if [[ -e "${AGE_IDENTITY_FILE}" ]]; then
  [[ -f "${AGE_IDENTITY_FILE}" && ! -L "${AGE_IDENTITY_FILE}" ]] || \
    fail "refusing to use a non-regular identity file: ${AGE_IDENTITY_FILE}"
  [[ -s "${AGE_IDENTITY_FILE}" ]] || fail "identity file is empty: ${AGE_IDENTITY_FILE}"
  printf 'Using existing age identity; it was not replaced.\n'
else
  printf 'Creating a new age identity for %s...\n' "${TARGET_USER}"
  run_as_target bash -c 'umask 077; exec age-keygen -o "$1"' _ \
    "${AGE_IDENTITY_FILE}"
fi

run_privileged chown "${TARGET_UID}:${TARGET_GID}" "${AGE_IDENTITY_FILE}"
run_privileged chmod 0600 "${AGE_IDENTITY_FILE}"

AGE_RECIPIENT="$(run_as_target age-keygen -y "${AGE_IDENTITY_FILE}")" || \
  fail "the identity file is not a valid age identity"

printf '\nAge identity is ready.\n'
printf '  Owner: %s (UID %s, GID %s)\n' "${TARGET_USER}" "${TARGET_UID}" "${TARGET_GID}"
printf '  Directory: %s (mode 0700)\n' "${AGE_DIRECTORY}"
printf '  Private identity: %s (mode 0600)\n' "${AGE_IDENTITY_FILE}"
printf '  OpenBao recovery artifact: %s/openbao-init.sops.json\n' "${AGE_DIRECTORY}"
printf '\nAdd this public value to ansible/vars/global.yml:\n\n'
printf 'openbao_age_recipient: "%s"\n' "${AGE_RECIPIENT}"
printf '\nBack up %s to a separate encrypted or physically secured location.\n' \
  "${AGE_IDENTITY_FILE}"

