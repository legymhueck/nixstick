# Scripts

`common/scripts.nix` installs each `<name>.sh` as the command `<name>`
(`writeShellApplication`: shellcheck at build time, dependencies on `PATH`).
To add one, put `<name>.sh` here, add a `mkScript` line with its runtime
dependencies, and list it in `docs/tips/commands.md` (usage examples for all
commands and aliases).

| Command | Purpose |
| --- | --- |
| `cycle-windows` | Focus the next window on any tag (`--prev`: the previous one); Super+Tab |
| `efi-traces` | List (or `--remove`) traces of earlier boots in a PC's firmware |
| `filen-sync` | Switch the Filen sync of `~/filen` on/off (`status`, `log`); see `docs/tips/filen.typ` |
| `format-and-mount` | Format and mount an encrypted LUKS + Btrfs partition |
| `lock-sync` | Update inputs, pin nixpkgs, Mango and hylki to the main repo's lock (cached builds), switch |
| `luks-header-backup` | Save the stick's LUKS header to a folder |
| `monitor-diagnose` | Record why a Thunderbolt/USB-C monitor stays black: kernel debug for thunderbolt and DRM during one guided replug, connector/bolt/output state before and after, saved to `~/monitor-diagnose/` (`--kurz`: state only) |
| `pi-sichern` | Back up the Raspberry Pi to the disk `pi-backup` (same script and restic repository as the main repo nixos): database dumps on the Pi, read-only SSHFS, restic; `--check`, `restic <args>`, `--ziel DIR` for another disk (off-site copy on schul-ssd); password in `~/.config/restic/pi-passwort` |
| `rpi-platte` | Mount your files on the Raspberry Pi (`rpi`, `~/samba/dateien`, the same as Nextcloud's folder `dateien`) at `~/rpi-platte` via SSHFS, at home and anywhere via Tailscale (`aus`, `status`); copied from the main repo nixos |
| `schul-ssd` | Open the school SSD (VeraCrypt slot 1) and `abgaben.hc` on it (slot 2) from the console, password asked once; `status`, `aus` (close both, power the SSD off), `--nur-ssd` |
| `schul-wlan` | Connect to the school Wi-Fi GymHueck (802.1X, PEAP/MSCHAPv2): creates the profile on first use, asks for user name and password; `status`, `aus`, `neu` |
| `spell-sync` | Merge Neovim's own spelling words (`dotfiles/nvim/spell/`) with the other repo (nixstick / the main repo nixos), then commit in both |
| `ssh-permissions` | Reset permissions in `~/.ssh` (700/600/644) |
| `tickets-sync` | Regio-IT tickets (mail from `service@regioit.de` in the LOGINEO mailboxes, read-only, subject only) become tasks in the Nextcloud list Tickets and are completed with the ticket; user timer every 15 min (`common/tickets.nix`); `setup` stores the passwords in the keyring (asks for each), `--dry-run`, `--days N` |
| `update-check` | Show which flake inputs have newer upstream commits (read-only) |
