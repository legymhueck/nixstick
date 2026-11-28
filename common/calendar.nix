# Calendars, tasks and contacts from Nextcloud on the Pi (CalDAV/CardDAV over
# Tailscale), shared by every app through Evolution Data Server:
# GNOME Online Accounts (account "Nextcloud") -> EDS -> GNOME Calendar,
# Endeavour (tasks) and hylki (mail; "Create Event/Task" from a mail).
# Without GNOME Settings the accounts are added with gnome-online-accounts-gtk
# (common/apps.nix). Phone side: docs/tips/phone.typ, section 8.
_:

{
  services.gnome.evolution-data-server.enable = true;
  services.gnome.gnome-online-accounts.enable = true;
  # GNOME Calendar and Endeavour keep their settings in dconf.
  programs.dconf.enable = true;
}
