#!/usr/bin/env bash
# Mount the disk of the Raspberry Pi at home (Tailscale name rpi, mounted there
# at /home/michael/samba) at ~/rpi-platte via SSHFS: a normal folder for Double
# Commander, Nautilus and every other program, at home and on the go
# (Tailscale). Uses the SSH key and the host entry rpi (common/home.nix).
# Copied from the main repo nixos; keep both in step.
#   rpi-platte           # mount (also adds a file chooser bookmark once)
#   rpi-platte aus       # unmount
#   rpi-platte status    # mounted or not
# Do not change the folders nextcloud, immich and postgres: they belong to the
# services on the Pi (main repo nixos: docs/platten.typ).
set -euo pipefail

usage() { awk '/^#!\/usr\/bin\/env bash/ { f = 1; next } f && /^#/ { sub(/^# ?/, ""); print; next } f { exit }' "$0"; }

ziel=$HOME/rpi-platte
quelle=rpi:/home/michael/samba
lesezeichen=${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/bookmarks

# Sessions started before the ssh-agent existed do not know its socket.
if [[ -z ${SSH_AUTH_SOCK:-} && -S ${XDG_RUNTIME_DIR:-/nonexistent}/ssh-agent ]]; then
  export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent
fi

case "${1:-an}" in
  an)
    # Bookmark for the GTK file chooser (and Nautilus); the file is created if
    # missing, an existing one is only appended to.
    if ! grep -qs "^file://$ziel " "$lesezeichen"; then
      mkdir -p "$(dirname "$lesezeichen")"
      echo "file://$ziel RPi-Platte" >>"$lesezeichen"
      echo "File chooser bookmark added: RPi-Platte"
    fi
    if mountpoint -q "$ziel"; then
      echo "Already mounted: $ziel"
      exit 0
    fi
    mkdir -p "$ziel"
    # reconnect + ServerAlive*: come back by themselves after Wi-Fi changes
    # or standby; idmap=user: files of michael on the Pi appear as yours.
    sshfs "$quelle" "$ziel" \
      -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user
    echo "Mounted: $ziel"
    ;;
  aus)
    if ! mountpoint -q "$ziel"; then
      echo "Not mounted: $ziel"
      exit 0
    fi
    if ! fusermount3 -u "$ziel"; then
      echo "Still in use (a terminal or program in $ziel?). Close it and try again." >&2
      exit 1
    fi
    echo "Unmounted: $ziel"
    ;;
  status)
    if mountpoint -q "$ziel"; then
      echo "Mounted: $ziel"
      df -h "$ziel" | tail -n 1
    else
      echo "Not mounted: $ziel"
    fi
    ;;
  -h | --help) usage ;;
  *)
    echo "Unknown argument: $1 (see --help)" >&2
    exit 2
    ;;
esac
