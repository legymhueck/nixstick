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
monitor-diagnose               # monitor stays black: record state + kernel log during one replug (sudo), before rebooting
monitor-diagnose --kurz        # state only, no debug, no replug
, cowsay hi                    # run a program from nixpkgs once without installing it (comma)
```

Super+L locks the screen at once. With several monitors, Super+Alt+Left/Right
moves the focused window to the neighbouring monitor, Alt+Shift+Left/Right moves
the focus there. Super+Tab / Super+Shift+Tab go through all windows on every
tag (`cycle-windows`), Super+Ctrl+Tab only those on the current tag; Alt+Tab
shows them all in the overview.

Touchpad: swipe 3 fingers left/right to move through the windows of the row,
up to open the overview and down to close it; 4 fingers left/right switch to
the next/previous tag with windows.

## School Wi-Fi (GymHueck)

GymHueck is WPA2 Enterprise (802.1X, PEAP with MSCHAPv2): it needs a user name
and a password. Noctalia's network applet did not set it up (2026-11-25: no
profile, no attempt in NetworkManager's log), so set it up once from the
terminal. Afterwards the applet shows GymHueck as a saved network and the stick
connects by itself; NetworkManager keeps the password in a root-only file.

```sh
schul-wlan                     # first time: asks for user name and password, then connects
schul-wlan BENUTZERNAME        # the same with the user name given (or change it)
schul-wlan neu                 # forget profile and password, set up again (wrong login)
schul-wlan status              # profile there? active?
schul-wlan aus                 # disconnect, the profile stays
```

What the script does, by hand:

```sh
nmcli connection add type wifi con-name GymHueck ssid GymHueck \
  wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2 \
  802-1x.identity BENUTZERNAME
nmcli --ask connection up GymHueck      # asks for the password
nmcli connection delete GymHueck        # start over
```

No CA certificate is set, so the stick does not check the server: a fake access
point named GymHueck could catch the login. If the school IT hands out a
certificate, add it with
`nmcli connection modify GymHueck 802-1x.ca-cert /path/to/ca.pem`.
If the connection fails, `journalctl -u NetworkManager -b` names the reason
(NetworkManager logs only warnings here, so it may be short).

## PDFs

PDFs and EPUBs open in zathura (`xdg-open`, Double Commander, and Neovim's
picker or explorer); Firefox is still there for filling in forms. In Neovim,
`<leader>sp` lists all PDFs (git-ignored exports too), `<leader>ro` opens the PDF that `<leader>re` exported; zathura reloads it on
every new export. In a `.typ` file, `<leader>rp` runs `typst watch` and opens the PDF in zathura: it updates on every save. Exports land in `out/` next to the source (git-ignored).
Printable cheat sheet: `docs/tips/zathura.typ`.

## Video

Videos and audio files open in mpv (`xdg-open`, Double Commander). mpv also
plays web videos directly via yt-dlp; `yt-dlp` alone downloads them.

```sh
mpv file.mp4                   # Space pause, ←/→ seek 5 s, ↑/↓ 1 min, f fullscreen
                               # 9/0 volume, m mute, [/] speed, s screenshot, q quit
mpv 'https://youtu.be/…'       # stream a web video
yt-dlp 'https://youtu.be/…'    # download it into the current directory
yt-dlp -x --audio-format mp3 'URL'   # audio only
```

## Spelling in Neovim

Markdown and Typst files are spell-checked (German and English). `]s` / `[s`
jump to the next / previous error, `z=` suggests, `zg` adds the word under the
cursor to your own list, `zw` marks it wrong, `zug` / `zuw` undo. Your own words
live in the repo (`dotfiles/nvim/spell/de.utf-8.add`), so commit them; the main
repo nixos has its own copy of the list: `spell-sync` merges both (it finds the
other repo under `~/GitHub`, or give its path), then commit in both repos.

```sh
spell-sync                     # merge own spelling words with the main repo nixos
```

```sh
zathura file.pdf               # j/k scroll, J/K or PgDn/PgUp page, gg/G start/end
                               # / search (n/N next/prev), Tab table of contents
                               # +/- zoom, a fit page, s fit width, Ctrl+r dark mode
                               # f follow a link, d two pages, r rotate, q quit
```

## Printing

The Kyocera FS-3820N on the home LAN is the default printer (`common/printing.nix`).
The OKI ES4132 has two queues: `OKI_ES4132_USB` (USB cable) and `OKI_ES4132_LAN` (192.168.0.103).

```sh
lp file.pdf                    # print (A4)
lp -o sides=two-sided-long-edge file.pdf   # both sides
lp -d OKI_ES4132_USB file.pdf  # print on the OKI (USB)
lpstat -p -d                   # printers and the default one
system-config-printer          # printer settings (GUI)
```

## Coding agents and editor

```sh
claude                         # Claude Code (first start: log in)
copilot                        # GitHub Copilot CLI (needs `gh auth login` / Copilot plan)
opencode                       # opencode
n                              # Neovim (nvim)
nn                             # Neovim in ~/nixos (the shell stays there)
nu                             # Neovim in ~/GitHub/unterricht (the shell stays there)
codium .                       # VSCodium in the current folder
gh auth login                  # GitHub login, also for git push over HTTPS
direnv allow                   # load a repo's .envrc (`use flake`) on cd
```

## VeraCrypt

Encrypted containers and volumes, compatible with VeraCrypt on Windows
(`common/apps.nix`). Mounting needs no sudo password (sudo rule for VeraCrypt's
core service in `common/base.nix`, as in the main repo nixos).

```sh
veracrypt                      # GUI: Select File, Mount
veracrypt -t container.hc ~/vc # text mode: mount the container at ~/vc
veracrypt -t -d                # dismount all
schul-ssd                      # school SSD (slot 1) + abgaben.hc (slot 2), password asked once
schul-ssd --nur-ssd            # only the school SSD
schul-ssd status               # what is open, and where
schul-ssd aus                  # close both, power the SSD off -- then unplug
```

Do not mount volumes on a foreign PC's internal disks: that writes to them.

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

## Full-text search (Recoll)

Searches the content of Office, ODF, PDF and Markdown files in `~/GitHub/unterricht`,
`~/filen/schule`, `~/filen/privat` and the main repo's `wissen/` (`common/apps.nix`).
The index is updated daily; German word forms by default.

```sh
recoll                         # search GUI
recollq WORD                   # search in the terminal (German stemming; -s english for English)
recollindex                    # update the index now (the first run takes a while)
```

## Mail

aerc reads over IMAP directly (no local copy), msmtp sends, the password comes
from pass (`common/mail.nix`; isync's `mbsync` is installed but not set up).
Full tutorial (setup, keys, troubleshooting): `docs/tips/aerc.typ`.

Once per stick:

```sh
gpg --full-generate-key        # ed25519 key; its passphrase is asked once per 8 h (pinentry window)
pass init <key-id or e-mail>   # create the store in ~/.local/share/password-store
pass insert mail/<address>     # the ACCOUNT password (not the GPG passphrase), one entry per address
```

Then add a `mkAccount` block per address in `common/mail.nix` and `rebuild`.

```sh
aerc                           # mail; ? lists the keys, :compose writes, :q quits
msmtp-queue -d                 # show mail queued while offline (msmtpq)
msmtp-queue -r                 # send the queue (once online again)
pass                           # list stored passwords
```

The GPG key lives only on this stick: back up `~/.gnupg` (e.g. with
`gpg --export-secret-keys -a`) to an encrypted place, or the store is lost
with the stick.

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

## Raspberry Pi disk (rpi-platte)

Your files on the Pi's disk as a normal folder `~/rpi-platte`, over SSH: at home and anywhere Tailscale is on, also
at school. It shows exactly what Nextcloud shows as the folder `dateien` (on the Pi `~/samba/dateien`, mounted via
the bindfs view `~/dateien`, so files you add stay editable in Nextcloud). The services' data (`docker.img`,
`immich`, `postgres`, `backups`) stays outside and is reached with `ssh rpi`. Samba (`smb://192.168.2.3/samba`)
shows the same folder but only works at home.

```sh
rpi-platte                     # mount at ~/rpi-platte (adds a bookmark "RPi-Platte" once)
rpi-platte status              # mounted or not, free space
rpi-platte aus                 # unmount (close programs that use it first)
```

Nextcloud notices changes made here when the folder is next opened there.

## Tickets as tasks (tickets-sync)

Regio-IT tickets (mail from `service@regioit.de` in the LOGINEO mailboxes) become tasks in the Nextcloud list
Tickets (phone: Tasks.org, PC: Endeavour), with only number and subject. A user timer runs it every 15 minutes;
the task is completed when the ticket's "wurde abgeschlossen" mail arrives.

```sh
tickets-sync setup             # once: asks for the password of each mailbox + the Nextcloud app password
tickets-sync --dry-run         # what would change
tickets-sync                   # run now (the timer does this every 15 minutes)
systemctl --user list-timers tickets-sync
```

## Raspberry Pi backup (pi-sichern)

Same backup as from the main system: plug in the disk `pi-backup`, mount it in the udiskie tray
(`/run/media/m/pi-backup`). The restic password is `~/.config/restic/pi-passwort` (from KeePassXC, once).

```sh
pi-sichern                     # dumps on the Pi, then restic (photos, Nextcloud, Paperless, Docker config)
pi-sichern --check             # now and then: verify the repository afterwards
pi-sichern restic snapshots    # list the snapshots
udisksctl unmount -b /dev/disk/by-label/pi-backup   # or unmount in the udiskie tray before unplugging
```

Off-site copy on the school SSD (VeraCrypt, mounted at `/tmp/veracrypt_mnt1`; the slot number can differ):
the same backup into its own restic repository `restic/pi` there, same password. Run it every few weeks.

```sh
pi-sichern --ziel /tmp/veracrypt_mnt1                     # back up to schul-ssd
pi-sichern --ziel /tmp/veracrypt_mnt1 restic snapshots    # its snapshots
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

## Phone (Pixel 6, ADB)

USB debugging on, plug in, tap Allow on the phone. Dial codes, settings paths,
IMS status and the debloat log: printable cheat sheet `docs/tips/phone.typ`.

```sh
, adb devices                  # "device" = ok, "unauthorized" = tap Allow on the phone
, scrcpy --no-audio            # show and control the phone screen in a window
, adb shell pm list packages -3   # apps you installed
newsflash                      # RSS reader on the stick; feeds from Feeder via OPML export
proton-authenticator           # 2FA codes (TOTP); import from other apps, Proton sync optional
```

One feed list for both readers: `~/filen/feeds.opml` (Filen keeps it in the
cloud). No sync of read status: after a change, import the file again in
Feeder (menu > Import feeds from OPML) and NewsFlash (menu > Import OPML).
