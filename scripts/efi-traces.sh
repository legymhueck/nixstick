#!/usr/bin/env bash
# Show what earlier boots left in this PC's firmware (EFI variables), and
# remove it on request. Since common/traceless.nix nothing is written any
# more; older versions of the stick (and NixOS on an SSD) left:
#   - LoaderSystemToken: a persistent random token from `bootctl random-seed`
#   - a boot entry "Linux Boot Manager" (only if installed with
#     canTouchEfiVariables = true on this PC)
#
#   efi-traces            # list only, changes nothing
#   efi-traces --remove   # delete them (asks first; needs sudo)
set -euo pipefail

remove=0
case ${1:-} in
  "") ;;
  --remove) remove=1 ;;
  -h | --help)
    echo "usage: efi-traces [--remove]"
    exit 0
    ;;
  *)
    echo "usage: efi-traces [--remove]" >&2
    exit 1
    ;;
esac

vars=/sys/firmware/efi/efivars
[[ -d $vars ]] || {
  echo "not booted with UEFI" >&2
  exit 1
}

token="$vars/LoaderSystemToken-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f"
found=0
if [[ -e $token ]]; then
  echo "found: LoaderSystemToken (persistent systemd-boot token)"
  found=1
fi
entries=$(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} \(Linux Boot Manager\).*/\1/p')
for e in $entries; do
  echo "found: boot entry Boot$e \"Linux Boot Manager\""
  found=1
done
if ((! found)); then
  echo "nothing found: this PC's firmware shows no traces of the stick"
  exit 0
fi
((remove)) || {
  echo "remove with: efi-traces --remove"
  exit 0
}

read -rp "Delete these from the PC's firmware? Type YES: " ans
[[ $ans == YES ]] || {
  echo "aborted"
  exit 1
}
# The variables are read-only (traceless.nix); open them only for this.
mount=$(command -v mount)
sudo "$mount" -o remount,rw "$vars"
trap 'sudo "$mount" -o remount,ro "$vars"' EXIT
if [[ -e $token ]]; then
  sudo "$(command -v chattr)" -i "$token"
  sudo rm -f -- "$token"
  echo "removed: LoaderSystemToken"
fi
for e in $entries; do
  sudo "$(command -v efibootmgr)" -q -b "$e" -B
  echo "removed: Boot$e"
done
