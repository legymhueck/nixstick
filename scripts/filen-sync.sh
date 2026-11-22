#!/usr/bin/env bash
# Switch the Filen sync of ~/filen (common/filen.nix) on or off. On stays on
# across logins and reboots until switched off.
set -euo pipefail

data="${XDG_CONFIG_HOME:-$HOME/.config}/filen-cli"
flag="$data/sync-enabled"
unit=filen-sync.service

usage() {
  cat <<USAGE
Usage: filen-sync on|off|status|log
  on      start syncing ~/filen with the whole Filen drive, also after reboots
  off     stop syncing (files in ~/filen stay)
  status  on or off, and the service state
  log     follow the sync log (Ctrl+C to quit)
USAGE
}

case "${1:-status}" in
  on)
    if [[ ! -e $data/.filen-cli-keep-me-logged-in ]]; then
      echo "Not logged in: run 'filen' once, log in and save the credentials." >&2
      exit 1
    fi
    mkdir -p "$data"
    touch "$flag"
    systemctl --user restart "$unit"
    echo "Filen sync is on (filen-sync log to watch it)."
    ;;
  off)
    rm -f "$flag"
    systemctl --user stop "$unit"
    echo "Filen sync is off."
    ;;
  status)
    if [[ -e $flag ]]; then echo "Switch: on"; else echo "Switch: off"; fi
    systemctl --user status --no-pager --lines=5 "$unit" || true
    ;;
  log)
    journalctl --user -u "$unit" -f
    ;;
  -h | --help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
