#!/usr/bin/env bash
# Open the school SSD (WD My Passport, whole disk VeraCrypt) and the container
# abgaben.hc on it from the console -- no VeraCrypt window needed.
#   schul-ssd            # SSD in slot 1, then abgaben.hc in slot 2
#   schul-ssd --nur-ssd  # only the SSD (bewertung/, unterricht-repo-spiegel/)
#   schul-ssd status     # what is open, and where
#   schul-ssd aus        # close both and power the SSD off -- then unplug it
# Asks for sudo first (VeraCrypt needs root to map the volume), then once for
# the VeraCrypt password; abgaben.hc is tried with the same password and asks
# again only if that fails. The password goes to VeraCrypt via stdin, never on
# the command line. Mount points come from VeraCrypt (/tmp/veracrypt_mntN or
# /run/media/veracryptN); backup and bewertung-sichern find both.
set -euo pipefail

usage() { awk '/^#!\/usr\/bin\/env bash/ { f = 1; next } f && /^#/ { sub(/^# ?/, ""); print; next } f { exit }' "$0"; }

# The internal disk of the WD My Passport; /dev/sdX changes, the by-id name
# does not. SCHUL_SSD_ID comes from common/devices.toml (via common/scripts.nix).
ssd_platte=/dev/disk/by-id/${SCHUL_SSD_ID:?not set: run the installed schul-ssd, not the .sh file}
ssd=$ssd_platte-part1
ssd_slot=1
abgaben_slot=2

# veracrypt -t -l: "<slot>: <volume> <mapper device> <mount point>"
liste() { veracrypt -t -l 2>/dev/null || true; }
einhaengepunkt() { # <volume path>  -> mount point, "" if not open
  local echt
  echt=$(readlink -f "$1")
  liste | awk -v a="$1" -v b="$echt" '$2 == a || $2 == b { print $4; exit }'
}

# open <volume> <slot> <label>; uses $passwort, asks again on a wrong password
oeffnen() {
  local vol=$1 slot=$2 name=$3 mp versuch
  mp=$(einhaengepunkt "$vol")
  if [[ -n $mp ]]; then
    echo "$name: already open at $mp"
    return 0
  fi
  for versuch in 1 2 3; do
    if [[ -z $passwort ]]; then
      read -rsp "VeraCrypt password for $name: " passwort
      echo
    fi
    echo "$name: opening ..."
    if printf '%s\n' "$passwort" | veracrypt -t --non-interactive --stdin --slot="$slot" \
      --pim=0 --keyfiles="" --protect-hidden=no "$vol" >/dev/null; then
      echo "$name: open at $(einhaengepunkt "$vol")"
      return 0
    fi
    echo "$name: could not open (wrong password? attempt $versuch of 3)" >&2
    passwort=""
  done
  return 1
}

status() {
  local mp
  if [[ ! -e $ssd ]]; then
    echo "School SSD: not plugged in"
  else
    mp=$(einhaengepunkt "$ssd")
    echo "School SSD: ${mp:-plugged in, closed} ($(readlink -f "$ssd"))"
    if [[ -n $mp ]]; then
      mp=$(einhaengepunkt "$mp/abgaben.hc")
      echo "abgaben.hc: ${mp:-closed}"
    fi
  fi
}

schliessen() {
  local mp
  mp=$(einhaengepunkt "$ssd")
  # abgaben.hc lives on the SSD: close it first
  if [[ -n $mp && -n $(einhaengepunkt "$mp/abgaben.hc") ]]; then
    veracrypt -t -d "$mp/abgaben.hc"
    echo "abgaben.hc: closed"
  fi
  if [[ -n $mp ]]; then
    veracrypt -t -d "$ssd"
    echo "School SSD: closed"
  fi
  if [[ -e $ssd_platte ]]; then
    sync
    udisksctl power-off -b "$ssd_platte"
    echo "School SSD: powered off -- you can unplug it now."
  fi
}

aktion=auf
abgaben=true
for a in "$@"; do
  case "$a" in
    status) aktion=status ;;
    aus) aktion=aus ;;
    --nur-ssd) abgaben=false ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $a (see --help)" >&2
      exit 2
      ;;
  esac
done

case $aktion in
  status) status ;;
  aus) schliessen ;;
  auf)
    if [[ ! -e $ssd ]]; then
      echo "School SSD not found ($ssd). Plug it in and wait a moment." >&2
      exit 1
    fi
    # VeraCrypt calls sudo itself and only skips its own password prompt while
    # a sudo timestamp is valid; refresh it here, on the terminal.
    sudo -v
    passwort=""
    oeffnen "$ssd" "$ssd_slot" "School SSD"
    if $abgaben; then
      mp=$(einhaengepunkt "$ssd")
      if [[ -f $mp/abgaben.hc ]]; then
        oeffnen "$mp/abgaben.hc" "$abgaben_slot" "abgaben.hc"
      else
        echo "abgaben.hc not found on the SSD ($mp) -- skipped." >&2
      fi
    fi
    passwort=""
    ;;
esac
