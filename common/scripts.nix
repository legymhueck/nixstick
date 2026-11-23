{ pkgs, ... }:

let
  # ../scripts/<name>.sh becomes the command <name>, checked by shellcheck at
  # build time and with its dependencies on PATH.
  # runtimeEnv: variables exported before the script runs (values from Nix).
  mkScriptEnv =
    name: runtimeInputs: runtimeEnv:
    pkgs.writeShellApplication {
      inherit name runtimeInputs runtimeEnv;
      text = builtins.readFile (../scripts + "/${name}.sh");
    };
  mkScript = name: runtimeInputs: mkScriptEnv name runtimeInputs { };
in
{
  home.packages = with pkgs; [
    (mkScript "cycle-windows" [ jq ])
    (mkScript "filen-sync" [
      coreutils
      systemd
    ])
    (mkScript "format-and-mount" [
      btrfs-progs
      cryptsetup
      util-linux
    ])
    (mkScript "efi-traces" [
      e2fsprogs # chattr
      efibootmgr
      util-linux # mount
    ])
    (mkScript "lock-sync" [
      gh
      jq
      nh
    ])
    (mkScript "luks-header-backup" [
      cryptsetup
      gawk
    ])
    # veracrypt and sudo come from the system PATH. The school SSD (WD My
    # Passport, serial 182906420963) is whole-disk VeraCrypt, so it has no
    # label or UUID: its name under /dev/disk/by-id/ (same value as the main
    # repo's common/devices.toml).
    (mkScriptEnv "schul-ssd" [
      coreutils
      gawk
      udisks
    ] { SCHUL_SSD_ID = "ata-MILAN_II_512G_182906420963"; })
    (mkScript "spell-sync" [
      coreutils
      diffutils
      findutils
      git
      gnugrep
      gnused
    ])
    (mkScript "ssh-permissions" [ findutils ])
    (mkScript "update-check" [
      curl
      git
      jq
    ])
  ];
}
