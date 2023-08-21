#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# shellcheck source=./../../pihero/files/lib/lib.bash
source "$SCRIPT_DIR/lib/lib.bash"

+diag() {
  local result init_system

  checks_start "System diagnostics"

  init_system=$(</proc/1/comm) || {
    printf "\e[31mFailed to determine the init system!\e[0m\n" >&2
    exit 1
  }

  case "$init_system" in
  systemd) ;;
  *)
    printf "\e[2mSkipping unsupported \e[3m%s\e[23m init system... \e[32m✔︎\e[0m\n" "$init_system" >&2
    return 0
    ;;
  esac

  check_unit "/boot/cmdline.txt"
  check "it contains no line breaks" grep -q "\n" /boot/cmdline.txt

  check_unit "$init_system"
  if ! check --brief "it's operational" systemctl -q is-system-running --wait; then
    local failed_unit failed_units=()
    while read -r line; do
      failed_units=("${failed_units[@]}" "$(echo "$line" | awk '{print $1}')")
    done < <(systemctl --failed --no-legend --no-pager)
    printf 'The following units failed: \e[3m%s\e[23m' "${failed_units[0]}" >&2
    [ "${#failed_units[@]}" -le 1 ] || printf ', \e[3m%s\e[23m' "${failed_units[@]:1}" >&2
    printf '\n' >&2

    for failed_unit in "${failed_units[@]}"; do
      printf '\n' >&2
      systemctl --no-pager status "$failed_unit"
    done
  fi

  check_summary
  result=$?

  {
    printf "\n\e[4mUseful commands:\e[0m\n"
    printf -- "- list all unit files: \e[3m%s\e[23m\n" 'systemctl list-unit-files'
    printf -- "- list failed units: \e[3m%s\e[23m\n" 'systemctl list-units --state=failed'
    printf -- "- check logs: \e[3m%s\e[23m\n" 'journalctl -b'
  } | sed 's/^/  /' >&2
  return $result
}
