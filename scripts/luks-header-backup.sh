#!/usr/bin/env bash
# Save the LUKS header of this stick. A damaged header (a few bytes at the
# start of the partition) makes the whole stick unreadable, even with the
# right passphrase; the copy brings it back (docs/tips/after-install.md).
# The copy is only useful with the passphrase, but keep it in an encrypted
# place anyway (VeraCrypt volume, KeePassXC attachment).
#
#   luks-header-backup <directory>     # e.g. a mounted, encrypted backup stick
set -euo pipefail

dir=${1:-}
if [[ -z $dir || $dir == -h || $dir == --help ]]; then
  echo "usage: luks-header-backup <directory>"
  exit 0
fi
[[ -d $dir ]] || {
  echo "not a directory: $dir" >&2
  exit 1
}

cryptsetup=$(command -v cryptsetup)
# The partition behind the open root container (cryptroot).
dev=$(sudo "$cryptsetup" status cryptroot | awk '$1 == "device:" { print $2 }')
[[ -b $dev ]] || {
  echo "cannot find the device of cryptroot" >&2
  exit 1
}
uuid=$(sudo "$cryptsetup" luksUUID "$dev")
file="$dir/luks-header-$(cat /proc/sys/kernel/hostname)-$uuid.img"
[[ ! -e $file ]] || {
  echo "exists already: $file" >&2
  exit 1
}
sudo "$cryptsetup" luksHeaderBackup "$dev" --header-backup-file "$file"
sudo chown "$(id -u):$(id -g)" "$file"
chmod 600 "$file"
echo "saved: $file"
