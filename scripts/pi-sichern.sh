#!/usr/bin/env bash
# Back up the Raspberry Pi (rpi) to the disk pi-backup attached to this machine
# (copied from the main repo nixos, keep both in step; both write the same
# restic snapshots, host rpi)
# (restic repository restic/pi, password ~/.config/restic/pi-passwort):
#   1. fresh dumps of the Nextcloud, Immich and Paperless databases on the Pi
#      (~/samba/backups/db-dumps, on the Pi's disk)
#   2. the Pi mounted read-only as root via SSHFS (sudo sftp-server on the Pi)
#   3. restic backup: the Pi's disk, the Nextcloud and Paperless Docker volumes,
#      ~/Docker (compose files, .env, Portainer); then forget + prune
#   pi-sichern                  # back up now
#   pi-sichern --check          # afterwards "restic check"
#   pi-sichern restic <args>    # restic with repository and password preset,
#                               # e.g. pi-sichern restic snapshots
# Needs: disk pi-backup mounted (udiskie tray), ssh rpi without prompt.
# Restore and details: the main repo nixos, docs/setup/raspberry-pi.typ.
set -euo pipefail

usage() { awk '/^#!\/usr\/bin\/env bash/ { f = 1; next } f && /^#/ { sub(/^# ?/, ""); print; next } f { exit }' "$0"; }

platte=/run/media/$USER/pi-backup
export RESTIC_REPOSITORY=$platte/restic/pi
export RESTIC_PASSWORD_FILE=$HOME/.config/restic/pi-passwort
wurzel=$XDG_RUNTIME_DIR/pi-root

if [[ -z ${SSH_AUTH_SOCK:-} && -S $XDG_RUNTIME_DIR/ssh-agent ]]; then
  export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent
fi

pruefen=false
case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  restic)
    shift
    exec restic "$@"
    ;;
  --check) pruefen=true ;;
  "") ;;
  *)
    echo "Unknown argument: $1 (see --help)" >&2
    exit 2
    ;;
esac

[[ -d $platte ]] || {
  echo "Disk pi-backup is not mounted ($platte). Plug it in and mount it in the udiskie tray." >&2
  exit 1
}
[[ -f $RESTIC_PASSWORD_FILE ]] || {
  echo "Password file missing: $RESTIC_PASSWORD_FILE (copy it from KeePassXC)." >&2
  exit 1
}
ssh -o BatchMode=yes -o ConnectTimeout=10 rpi true 2>/dev/null || {
  echo "ssh rpi needs a prompt or the Pi is unreachable. Run ssh-add, check Tailscale." >&2
  exit 1
}

if ! restic cat config >/dev/null 2>&1; then
  echo "==> Creating the restic repository $RESTIC_REPOSITORY"
  mkdir -p "$RESTIC_REPOSITORY"
  restic init
fi

echo "==> Database dumps on the Pi"
# Each dump goes to a temp file first and only replaces the previous one when
# its last line shows that it is complete.
ssh -o BatchMode=yes rpi bash -s <<'REMOTE'
set -euo pipefail
d=$HOME/samba/backups/db-dumps
mkdir -p "$d"
dump() { # name, container, command run inside the container, end marker
  local tmp="$d/.$1.sql.tmp"
  sudo docker exec "$2" sh -c "$3" >"$tmp"
  if tail -n 3 "$tmp" | grep -q "$4"; then
    mv "$tmp" "$d/$1.sql"
    chmod 600 "$d/$1.sql"
    printf '  %-10s %s\n' "$1" "$(du -h "$d/$1.sql" | cut -f1)"
  else
    echo "  $1: dump incomplete, previous dump kept" >&2
    rm -f "$tmp"
    return 1
  fi
}
dump nextcloud nextcloud_db \
  'exec mariadb-dump -u root -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --databases "$MYSQL_DATABASE"' \
  'Dump completed'
dump immich immich_postgres \
  'exec pg_dumpall --clean --if-exists -U "$POSTGRES_USER"' \
  'database cluster dump complete'
dump paperless paperless-db-1 \
  'exec pg_dumpall --clean --if-exists -U "$POSTGRES_USER"' \
  'database cluster dump complete'
REMOTE

echo "==> Mounting the Pi read-only"
mkdir -p "$wurzel"
mountpoint -q "$wurzel" || sshfs -o ro,reconnect,ServerAliveInterval=15 \
  -o sftp_server="/usr/bin/sudo /usr/lib/openssh/sftp-server" rpi:/ "$wurzel"
trap 'fusermount3 -u "$wurzel" 2>/dev/null || true; rmdir "$wurzel" 2>/dev/null || true' EXIT

echo "==> restic backup"
# --ignore-inode: SSHFS has no stable inode numbers; without it restic would
# re-read every file each time. The raw Immich database (postgres/, plus an old
# cluster kept after a major upgrade, e.g. postgres.pg14) and the
# Nextcloud apps are left out: the dump replaces the first, the App Store
# restores the second. docker.img (ext4 image mounted at /var/lib/docker) is
# left out as a whole; the volumes inside are backed up by their paths.
restic backup --host rpi --tag pi --ignore-inode \
  --exclude "$wurzel/home/michael/samba/postgres*" \
  --exclude "$wurzel/home/michael/samba/.Trash-*" \
  --exclude "$wurzel/home/michael/samba/docker.img" \
  --exclude "$wurzel/var/lib/docker/volumes/docker_nextcloud/_data/custom_apps" \
  "$wurzel/home/michael/samba" \
  "$wurzel/home/michael/Docker" \
  "$wurzel/var/lib/docker/volumes/docker_nextcloud/_data" \
  "$wurzel/var/lib/docker/volumes/paperless_data/_data" \
  "$wurzel/var/lib/docker/volumes/paperless_media/_data"

echo "==> Removing old snapshots"
restic forget --host rpi --prune \
  --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 3

if $pruefen; then
  echo "==> restic check"
  restic check
fi
echo "==> Done. Snapshots: pi-sichern restic snapshots"
