# Regio-IT service tickets become tasks in the Nextcloud list "Tickets"
# (scripts/tickets-sync.py): every 15 minutes the LOGINEO mailboxes are read
# (IMAP, read-only, only Subject and Date of mail from service@regioit.de) and
# one task per ticket number is created, then completed when the ticket's
# "wurde abgeschlossen" mail arrives. Only number and subject go into the task.
# Passwords: GNOME Keyring entries of its own, `tickets-sync setup` stores them.
{ pkgs, ... }:

let
  tickets-sync = pkgs.writeShellApplication {
    name = "tickets-sync";
    runtimeInputs = [
      pkgs.python3
      pkgs.libsecret # secret-tool
    ];
    runtimeEnv.TICKETS_SYNC_PY = ../scripts/tickets-sync.py;
    text = builtins.readFile ../scripts/tickets-sync.sh;
  };
in
{
  home.packages = [ tickets-sync ];

  systemd.user.services.tickets-sync = {
    Unit.Description = "Regio-IT tickets to Nextcloud tasks";
    # Never started by a switch: a run takes minutes (all folders of five
    # mailboxes) and the switch would wait for it; the timer picks up changes.
    Unit.X-RestartIfChanged = false;
    Service = {
      Type = "oneshot";
      ExecStart = "${tickets-sync}/bin/tickets-sync";
    };
  };
  systemd.user.timers.tickets-sync = {
    Unit.Description = "Regio-IT tickets to Nextcloud tasks, every 15 minutes";
    Timer = {
      OnStartupSec = "5min";
      OnUnitActiveSec = "15min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
