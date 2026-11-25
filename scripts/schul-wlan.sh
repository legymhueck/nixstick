#!/usr/bin/env bash
# Connect to the school Wi-Fi GymHueck (WPA2 Enterprise, 802.1X: PEAP with
# MSCHAPv2). Creates the NetworkManager profile on first use, then connects;
# NetworkManager keeps the password (root-only file in
# /etc/NetworkManager/system-connections), so later it connects by itself.
set -euo pipefail

con=GymHueck
ssid=GymHueck

usage() {
  cat <<USAGE
Usage: schul-wlan [BENUTZERNAME]|neu|status|aus
  (none)  connect; on first use asks for the user name, then the password
  NAME    create the profile with this user name (or change it), then connect
  neu     forget profile and password, set up again (wrong name or password)
  status  is the profile there, is it active
  aus     disconnect (the profile stays)
USAGE
}

exists() { nmcli -t -f NAME connection show | grep -qxF "$con"; }

create() {
  local user=$1
  if [[ -z $user ]]; then
    read -rp "Benutzername für $ssid: " user
  fi
  [[ -n $user ]] || {
    echo "No user name given." >&2
    exit 1
  }
  if exists; then
    nmcli connection modify "$con" 802-1x.identity "$user"
  else
    # No CA certificate: the school does not hand one out, so the server is
    # not verified (see docs/tips/commands.md).
    nmcli connection add type wifi con-name "$con" ssid "$ssid" \
      wifi-sec.key-mgmt wpa-eap \
      802-1x.eap peap 802-1x.phase2-auth mschapv2 \
      802-1x.identity "$user" 802-1x.password-flags 0
  fi
}

connect() {
  # --ask: nmcli asks for the password itself, so it never shows up in the
  # shell history or the process list.
  nmcli --ask connection up "$con"
}

case "${1:-}" in
  -h | --help) usage ;;
  status)
    if exists; then
      nmcli -f connection.id,802-1x.identity,GENERAL.STATE connection show "$con"
    else
      echo "No $con profile yet: run schul-wlan."
    fi
    ;;
  aus) nmcli connection down "$con" ;;
  neu)
    if exists; then nmcli connection delete "$con"; fi
    create ""
    connect
    ;;
  "")
    exists || create ""
    connect
    ;;
  -*)
    usage >&2
    exit 1
    ;;
  *)
    create "$1"
    connect
    ;;
esac
