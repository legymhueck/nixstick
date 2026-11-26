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
  # Thunderbolt devices authorized already in the initrd (common/base.nix), so
  # a keyboard on their USB hub works at the LUKS prompt; boltd only starts
  # after it. unique_id as `boltctl list` prints it (uuid). The same device as
  # in the main repo nixos (common/devices.toml).
  thunderboltInitrd = [
    {
      name = "LG 38WN95C (monitor, USB hub with the Omoton keyboard)";
      unique_id = "c8010000-0062-6c1e-0377-f0856c426202";
    }
  ];
  # Own disks that udiskie mounts as soon as they are plugged in (allow-list,
  # nixos-mango/desktop.nix); LUKS ones ask for the passphrase first, every
  # other drive waits for a click in the tray. A copy of the disks with
  # `automount = true` in the main repo nixos (common/devices.toml, overview
  # docs/platten.typ there): change them there first, then here.
  # luks_uuid / fs_uuid as `lsblk -o NAME,FSTYPE,LABEL,UUID` prints them.
  automountDisks = [
    {
      label = "restic-backup";
      fs_uuid = "d829cb25-b8b2-4c47-8e0a-413edb75df73";
    }
    {
      label = "restic-backup-2";
      luks_uuid = "788752bd-1004-468c-8072-154f33f9beed";
      fs_uuid = "0662e040-7571-4f8a-a46b-8e4cd2b8e323";
    }
    {
      label = "nicht-unterricht";
      luks_uuid = "e9910e5d-d5a5-4128-954c-bbcb287a4587";
      fs_uuid = "5a935720-89c0-4f2a-a703-6a3915da1411";
    }
    {
      label = "bewertung";
      luks_uuid = "190430a8-ab46-4e93-9503-c4d4baecdaba";
    }
    {
      label = "pi-backup";
      fs_uuid = "f78a992d-edb8-4396-ab50-ee8cdeaa500a";
    }
    {
      label = "Ventoy";
      fs_uuid = "732D-F623";
    }
    {
      label = "LE";
      fs_uuid = "7865-8A70";
    }
  ];
  # Btrfs subvolume mount points (@, @home, @nix, @log, created by install.sh).
  btrfsMounts = [
    "/"
    "/home"
    "/nix"
    "/var/log"
  ];
}
