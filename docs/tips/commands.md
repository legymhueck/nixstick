# Commands worth remembering

Every command below has `--help`. Own commands come from `scripts/` (see
`scripts/README.md`); aliases and functions are in `common/home.nix`.

## System

```sh
rebuild                        # nh os switch: apply the configuration
update                         # lock-sync: update inputs, pin nixpkgs + Mango to the main repo (cached), apply
lock-sync --no-switch          # the same, only flake.lock
nh os test                     # try a configuration without a boot entry
nh clean all --keep 5          # remove old generations now (also runs weekly)
nix flake check                # lint and evaluate (in ~/nixos)
```

### Is an update worth it?

```sh
update-check                   # which inputs have newer commits (changes nothing)
nh os build --update           # in ~/nixos: build the update, list changed packages, don't switch
rebuild                        # then apply it ...
git checkout flake.lock        # ... or throw the update away
```

## Drives

```sh
mnt /dev/sdb1                  # mount a USB partition (udisksctl)
format-and-mount               # WIPE a drive, set it up as LUKS + Btrfs, mount it
umount-drive                   # unmount ~/mount and close the "micleh" LUKS mapper
partuuid                       # list partitions by PARTUUID
luks-header-backup ~/mount     # save this stick's LUKS header (once, to an encrypted place)
```

### Stick speed

A USB stick has one I/O queue (queue depth 1 with `usb-storage`). A large
write, e.g. a rebuild, makes the whole desktop wait. `ionice -c3` (class
"idle") gives a command disk time only when nothing else wants it, so the
desktop stays responsive and the command takes a little longer.

```sh
ionice -c3 nh os switch        # rebuild at idle I/O priority (works with any command, e.g. update)
lsblk -o NAME,SIZE,TRAN,MODEL,MOUNTPOINTS   # which drive is which, USB or internal
lsusb -t                       # USB link speed per device (480M = USB 2, 5000M = USB 3) and driver (uas is faster than usb-storage)
cat /sys/block/sda/device/queue_depth       # 1 = one command at a time
# random 4k reads, read-only, ~20 s; compare sticks (replace sda)
sudo "$(nix build --no-link --print-out-paths nixpkgs#fio)/bin/fio" --name=r --filename=/dev/sda \
  --rw=randread --bs=4k --direct=1 --runtime=20 --time_based --readonly
```

## Foreign PCs

```sh
efi-traces                     # does this PC's firmware show traces of a boot? (read-only)
efi-traces --remove            # delete them (asks, sudo)
, cowsay hi                    # run a program from nixpkgs once without installing it (comma)
```

Super+L locks the screen at once. With several monitors, Super+Alt+Left/Right
moves the focused window to the neighbouring monitor, Alt+Shift+Left/Right moves
the focus there. Super+Tab / Super+Shift+Tab go through all windows on every
tag (`cycle-windows`), Super+Ctrl+Tab only those on the current tag; Alt+Tab
shows them all in the overview.

## Printing

The Kyocera FS-3820N on the home LAN is the default printer (`common/printing.nix`).

```sh
lp file.pdf                    # print (A4)
lp -o sides=two-sided-long-edge file.pdf   # both sides
lpstat -p -d                   # printers and the default one
system-config-printer          # printer settings (GUI)
```

## Coding agents and editor

```sh
claude                         # Claude Code (first start: log in)
copilot                        # GitHub Copilot CLI (needs `gh auth login` / Copilot plan)
opencode                       # opencode
codium .                       # VSCodium in the current folder
gh auth login                  # GitHub login, also for git push over HTTPS
direnv allow                   # load a repo's .envrc (`use flake`) on cd
```

## Filen cloud

`~/filen` syncs two-way with the whole Filen drive while the switch is on
(`common/filen.nix`; printable guide: `docs/tips/filen.typ`).

```sh
filen                          # once: log in and save the credentials (also: browse the drive)
filen-sync on                  # start syncing, stays on after reboots
filen-sync off                 # stop syncing (the files in ~/filen stay)
filen-sync status              # on or off, service state
filen-sync log                 # follow the sync log
```

## Btrfs

```sh
bfree                          # Btrfs space usage
bscrub && bscrubStatus         # check the file system for errors
```

## SSH and keys

```sh
create-ssh-key                 # ssh-keygen -t ed25519
ssh-permissions                # fix permissions in ~/.ssh
fingerprint                    # enroll a fingerprint (fprintd) -- only on your own devices
```

## Everyday helpers

```sh
ex archive.tar.gz              # extract almost any archive
l                              # eza -al --icons
bigFiles                       # sizes of everything below ., largest last
battery                        # battery details
sf                             # failed systemd units
journalInfo                    # errors of the current boot
programPath firefox            # where a command really lives in /nix/store
```
