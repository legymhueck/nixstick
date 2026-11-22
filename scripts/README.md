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
| `lock-sync` | Update inputs, pin nixpkgs + Mango to the main repo's lock (cached Mango), switch |
| `luks-header-backup` | Save the stick's LUKS header to a folder |
| `spell-sync` | Merge Neovim's own spelling words (`dotfiles/nvim/spell/`) with the other repo (nixstick / the main repo nixos), then commit in both |
| `ssh-permissions` | Reset permissions in `~/.ssh` (700/600/644) |
| `update-check` | Show which flake inputs have newer upstream commits (read-only) |
