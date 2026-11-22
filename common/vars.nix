# Single source for names used by the flake, NixOS and Home Manager modules
# (as the `vars` module argument), and by install.sh (read with
# nix-instantiate). Plain data: no arguments.
{
  user = "m";
  # Name of the configuration, not a hostname: the evaluation twin
  # (nixstick-eval). Hostnames are the directory names in hosts/ (nixstick, ...).
  project = "nixstick";
  # Fixed origin of the FIDO2 key (common/yubikey.nix). The same as in the main
  # repo nixos (pam://nixbox), so one registration (common/u2f_keys) works on
  # every stick and on the SSD.
  yubikeyOrigin = "pam://nixbox";
  # Btrfs subvolume mount points (@, @home, @nix, @log, created by install.sh).
  btrfsMounts = [
    "/"
    "/home"
    "/nix"
    "/var/log"
  ];
}
