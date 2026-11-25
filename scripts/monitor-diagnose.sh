#!/usr/bin/env bash
# Record why a Thunderbolt/USB-C monitor shows no picture, BEFORE rebooting.
# The kernel logs DP tunnel setup (thunderbolt) and DP link training (drm)
# only with debug output; this turns both on for one replug, saves the state
# before and after plus the kernel log, and turns debug off again.
# Writes only kernel debug switches (RAM), nothing to firmware or the monitor.
#
#   monitor-diagnose          # asks for sudo, guides through one replug
#   monitor-diagnose --kurz   # state only, no debug, no replug
set -euo pipefail

usage() { echo "usage: monitor-diagnose [--kurz]"; }
short=0
case ${1:-} in
  "") ;;
  --kurz) short=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

out="$HOME/monitor-diagnose/$(date +%Y-%m-%d_%H%M%S)"
mkdir -p "$out"
start=$(date '+%Y-%m-%d %H:%M:%S')

snapshot() {
  local f="$out/$1.txt"
  {
    echo "### $(date '+%F %T') $1"
    echo "### DRM connectors"
    for c in /sys/class/drm/card*-*; do
      [[ -e $c/status ]] || continue
      printf '%s: %s, enabled=%s\n' "${c##*/}" "$(cat "$c/status")" "$(cat "$c/enabled" 2>/dev/null || echo ?)"
    done
    echo "### Thunderbolt devices (boltctl)"
    boltctl list 2>&1 || true
    echo "### Wayland outputs (wlr-randr)"
    if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
      wlr-randr 2>&1 || true
    else
      echo "no WAYLAND_DISPLAY (run from a terminal in Mango for this part)"
    fi
  } >"$f"
  echo "saved: $f"
}

drm_debug=/sys/module/drm/parameters/debug
dyndbg=/sys/kernel/debug/dynamic_debug/control
debug_on=0
debug_off() {
  ((debug_on)) || return 0
  echo 0 | sudo tee "$drm_debug" >/dev/null || true
  echo 'module thunderbolt -p' | sudo tee "$dyndbg" >/dev/null || true
  echo "kernel debug output off again"
}
trap debug_off EXIT

snapshot vorher
if ((short)); then
  journalctl -k -b --no-pager | grep -iE 'thunderbolt|i915|typec|\(DP\)|xhci' >"$out/kernel.txt" || true
  echo "saved: $out/kernel.txt"
  exit 0
fi

echo "Turning on kernel debug output for thunderbolt and DRM (sudo) ..."
# drm.debug bits: 0x04 KMS, 0x10 atomic, 0x100 DP (AUX, link training, MST)
echo 0x114 | sudo tee "$drm_debug" >/dev/null
echo 'module thunderbolt +p' | sudo tee "$dyndbg" >/dev/null
debug_on=1

read -rp "Unplug the monitor cable from the laptop, then press Enter. "
sleep 3
read -rp "Plug it back in, then press Enter. "
echo "Waiting 20 s for the monitor ..."
sleep 20

snapshot nachher
debug_off
debug_on=0
journalctl -k --since "$start" --no-pager >"$out/kernel.txt"
journalctl --user --since "$start" --no-pager >"$out/user.txt" || true
echo "saved: $out/kernel.txt, $out/user.txt"
echo
echo "Quick look (connected? tunnel? link training?):"
grep -iE '\(DP\)|tunnel|link train|DP-[0-9].*(connected|disconnected)' "$out/kernel.txt" | tail -n 15 || true
echo
echo "Done. Now try suspend/resume, otherwise reboot. Keep $out for the analysis."
