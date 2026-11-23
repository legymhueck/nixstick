# NixOS

Personal, reproducible NixOS workstation configuration: a minimal MangoWM desktop with Home Manager, shared dotfiles, local packages and a single-step installer.

## Layout

| Path | Purpose |
| --- | --- |
| `flake.nix`, `flake.lock` | Single entry point, all inputs pinned. `nixosConfigurations.<hostname>` exists for every `hosts/<hostname>/hardware-configuration.nix` (the `nixstick-eval` twin with a `/dev/null` stand-in is for CI and `nix eval`, never deploy). Also exports a dev shell with the linters (`nix develop`) and the formatter |
| `hosts/` | One directory per installed stick (`nixstick`, ...): its generated `hardware-configuration.nix`, optionally `host.nix` (settings for that stick only). Created by `install.sh` |
| `common/` | `vars.nix` (user, project name, YubiKey origin, Btrfs mounts), `base.nix` (system + essential CLI tools + unfree allowlist), `traceless.nix` (nothing is written to a foreign PC: firmware, TPM, clock, disks), `printing.nix` (CUPS and the queue for the home printer, network only), `yubikey.nix` + `u2f_keys` (FIDO2 key for sudo, login, lock screen), `hardware-portable.nix` (generic Intel/AMD support so the stick boots on any x86 PC), `home.nix` (shell, git, starship, ...), `apps.nix` (the single spot for applications, free and unfree), `neovim.nix` (Neovim with plugins and language servers; Lua config in `dotfiles/nvim/lua/m`), `firefox.nix` (browser), `mail.nix` (aerc + msmtp + pass/GPG, the mail account), `scripts.nix` |
| `nixos-mango/` | MangoWM + Noctalia: `configuration.nix` (Mango system side, login, keyring), `desktop.nix` (Mango/Noctalia Home Manager), `home.nix` (qt5ct/qt6ct theming, MIME defaults) |
| `wallpapers/` | Noctalia wallpaper source (`desktop.nix` points to `~/nixos/wallpapers`); `minimal-dark.png` is self-generated, no license restrictions |
| `dotfiles/` | Files that Home Manager links (doublecmd, mc, starship, nvim) |
| `scripts/` | Shell scripts, installed as commands by `common/scripts.nix` |
| `install.sh` | Disk-wiping installer for the NixOS minimal ISO: installs everything (browser, applications, local packages) in one step |
| `docs/tips/` | Handouts; `docs/tips/commands.md` is a cheat sheet of everyday commands |
| `.github/workflows/` | CI: format, lint and evaluation |

## Install

Boot the NixOS minimal ISO (UEFI), connect to the network (`nmtui`), then:

```sh
# gh is NOT on the minimal ISO ("gh: command not found"): load it first.
nix-shell -p gh git                   # gh and git for the live system only (RAM), takes a minute
gh auth login -h github.com -p https -w   # login by code, no menus; works on a bare tty:
                                      # Enter (no browser opens), open github.com/login/device
                                      # on a phone, enter the code; Git credentials: Y
gh repo clone legymhueck/nixstick nixos
cd nixos
lsblk                                 # identify the target disk
sudo ./install.sh /dev/sdb nixstick2  # target USB stick, a new hostname (MangoWM + Noctalia)
reboot
```

The system is meant to live on a fast USB stick (USB 3, 64 GB or more) or a USB SSD and boots on any x86_64 UEFI PC, Intel or AMD. It leaves no traces on the PCs it boots on (`common/traceless.nix`): no boot entries or other variables in the firmware (`canTouchEfiVariables = false`, read-only EFI variables), nothing in the TPM, no write to the hardware clock, internal disks hidden. The firmware finds it through the removable-media path `EFI/BOOT/BOOTX64.EFI`, so pick the stick in the one-time boot menu; never change the firmware settings (Secure Boot must already be off; see `docs/tips/after-install.md`). To spare the flash, the journal and `/tmp` live in RAM (logs are gone after a reboot), there are no snapper snapshots and no automatic store optimisation.

The GitHub login works whether the repository is public or private and lives only in the live system's RAM: no token is stored, and the copied `.git` holds only the repository address. For a public repository `git clone https://github.com/legymhueck/nixstick.git nixos` works without a login. Never put a token into the clone URL (`https://<token>@github.com/...`): it would end up in `.git/config` and be copied to the stick. After the install `gh` is part of the system (`programs.gh` in `common/home.nix`); log in once more there (`docs/tips/after-install.md`).

The hostname names the new directory `hosts/<hostname>/`; the installer refuses one that exists already, so every stick keeps its own hardware module. The script copies the complete checkout (with `.git`) to `~/nixos`, so it is a working clone afterwards (set the remote or keep it local). It **erases the whole disk** after you type `YES`, and refuses disks with mounted partitions (the installer stick). It creates GPT/EFI, LUKS2 and Btrfs subvolumes (`@`, `@home`, `@nix`, `@log`, zstd) and installs. A temporary swap file is used only during the install and deleted at the end; the installed system uses zram.

The script asks for **one password**. It becomes the LUKS passphrase and the password of `m`. Root login is disabled (use `sudo`).

Almost everything comes from the binary caches — the free applications and system packages from cache.nixos.org, the Noctalia shell from its Cachix cache, Mango from the main repo's Cachix cache `nixbox-m` when nixpkgs and Mango are pinned to the main repo's lock (`lock-sync`). The unfree packages (`claude-code`, `github-copilot-cli`, `copilot-language-server`, the Claude VSCodium extension) are not on cache.nixos.org; Nix packages them locally from the upstream release files during the install (download and wrap, no compiling). Without that pin the Mango compositor is built from its flake input (a small C build, about a minute). Keep it that way: nothing that compiles for long belongs on the stick — check with `nix build --dry-run .#nixosConfigurations.nixstick-eval.config.system.build.toplevel` ("will be built" vs. "will be fetched").

## Login

1. Power on, type the disk passphrase.
2. The desktop starts by itself, no login screen (boot only; after a logout or compositor crash tuigreet asks for the password).
3. The lock screen asks for the same password.

So there is exactly one password.

### Changing the password

The disk passphrase and the account password must stay identical:

```sh
sudo cryptsetup luksChangeKey /dev/disk/by-partlabel/nixos
passwd
```

## Daily use

```sh
nh os switch            # alias: rebuild. Apply the configuration
lock-sync               # alias: update. Update all inputs, pin nixpkgs + Mango to the main repo, apply
nh os test              # activate without a boot entry
```

Old generations are removed weekly (`programs.nh.clean`, keeps 5 and 14 days). Check with `nix flake check` (lint and evaluation of all outputs) and `nix eval .#nixosConfigurations.nixstick-eval.config.system.build.toplevel.drvPath` before pushing; CI runs the same. Format with `nix fmt`. `nix develop` gives a shell with statix, deadnix, nixfmt, shellcheck and shfmt.

### Notes for a future application or package

- A nixpkgs application (free or unfree) goes into `common/apps.nix` — the one spot for applications. Unfree ones additionally need their pname in the allowlist in `common/base.nix`.
- No own packages: everything comes from nixpkgs. If one is ever needed, copy it from the main repo (its `pkgs/`), but only if it does not compile for long.
- A new user-facing command, alias or script: `docs/tips/commands.md`.
- Qt apps inherit the Noctalia palette from the qt5ct/qt6ct setup in `nixos-mango/`. Double Commander from nixpkgs is Qt5, so it is themed through qt5ct even though `QT_QPA_PLATFORMTHEME` is set to `qt6ct`.

## Reproducibility

- Every input is locked in `flake.lock`; `nix shell nixpkgs#...` and `<nixpkgs>` use the system's own nixpkgs revision (registry + `nixPath`).
- No package is pinned to another nixpkgs revision. If one breaks on unstable, add a `nixpkgs-stable` input and take only that package from it (an overlay in `common/base.nix`); drop it again once unstable is cached.
- The Noctalia official and community plugin sources are pinned in `flake.lock` and exposed to Noctalia as immutable Nix store paths, so plugin code is not fetched at runtime.

## Notes

- Hostname `nixstick` (until 2026-11-17 `nixbox`, the same as the main system). A stick installed before that: `cd ~/nixos && git pull && nh os switch -H nixstick` once (plain `rebuild` looks up the old hostname), see `docs/tips/after-install.md` ("Sticks installed before 2026-11-17"; in Tailscale remove an old entry only if it is a second, offline device).
- Starting a fresh repo from these files (new `.git`): `git init && git add -A && git commit -m "Initial import"`. Flakes read working-tree files through git, so the files must be tracked before `nix flake check` / `nh os switch` work.
- `flake.lock` may contain entries for inputs no longer in `flake.nix` (e.g. after removing a local package); they are ignored and pruned on the next `nix flake update`.
- `hosts/<hostname>/hardware-configuration.nix` belongs to that stick only; never move it to another directory. A pre-switch check aborts activation if a disk of the configuration is missing.
- Do not change `system.stateVersion` / `home.stateVersion` during routine updates.
- More detail: `AGENTS.md`.
