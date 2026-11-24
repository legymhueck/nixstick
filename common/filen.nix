{ pkgs, vars, ... }:

let
  dataDir = "%h/.config/filen-cli";
in
{
  # Filen cloud sync: ~/filen <-> the whole Filen drive, two-way, with the
  # official filen-cli (package in ./apps.nix). Off until `filen-sync on`; once
  # on, it keeps syncing and comes back after every login and reboot until
  # `filen-sync off` (scripts/filen-sync.sh, docs/tips/filen.typ).
  #
  # The switch is a flag file, not `systemctl --user enable`: Home Manager
  # links units with WantedBy itself, so a manual disable would not survive the
  # next login. The unit is always wanted and skips itself while the flag (or
  # the saved login from `filen`) is missing.

  # filen-cli reads its sync pairs from its data directory. Dot files stay
  # local; the local trash is off, as in the main repo nixos (with Filen on two
  # systems it broke the sync).
  xdg.configFile."filen-cli/syncPairs.json".text = builtins.toJSON [
    {
      local = "/home/${vars.user}/filen";
      remote = "/";
      syncMode = "twoWay";
      alias = "drive";
      excludeDotFiles = true;
      disableLocalTrash = true;
    }
  ];

  systemd.user.services.filen-sync = {
    Unit = {
      Description = "Filen sync of ~/filen (filen-sync on/off)";
      ConditionPathExists = [
        "${dataDir}/sync-enabled"
        "${dataDir}/.filen-cli-keep-me-logged-in"
      ];
      # Keep retrying while offline; never give up.
      StartLimitIntervalSec = 0;
    };
    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/filen";
      # --skip-update: the built-in updater cannot replace a store path.
      ExecStart = "${pkgs.filen-cli}/bin/filen --skip-update --quiet sync --continuous";
      Restart = "on-failure";
      RestartSec = 30;
      # The stick has one I/O queue: sync only when the desktop is idle.
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
