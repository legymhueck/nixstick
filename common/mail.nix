{ config, pkgs, ... }:

{
  # Mail in the terminal: aerc reads over IMAP directly (no local Maildir:
  # nothing to sync, no mail copies and fewer writes on the stick), msmtp sends
  # (aerc hands mail to msmtpq, which queues it while offline). Passwords come
  # from pass (GPG-encrypted, ~/.local/share/password-store). isync (mbsync) is
  # installed for manual use only; no account is synced.
  #
  # First run (once per stick): create a GPG key and the store, then the mail
  # password, see docs/tips/aerc.typ (printable tutorial).

  # One block per address. The attribute name (e.g. `gymhueck`) is the tab in
  # aerc and the msmtp account (`msmtp -a gymhueck`); the password is the pass
  # entry `mail/<address>` (`pass insert mail/<address>`). For another address
  # copy a block with a new name; `primary = true` only on one of them (it is
  # the default sender and the first tab).
  accounts.email.accounts =
    let
      # Defaults for an account whose servers speak TLS from the first byte
      # (IMAP 993, SMTP 465). For SMTP on 587 override `smtp` with
      # `{ host = "..."; port = 587; tls.useStartTls = true; }`.
      mkAccount =
        {
          address,
          host,
          realName ? "Michael Lehnen",
          ...
        }@args:
        {
          inherit address realName;
          userName = address;
          passwordCommand = "pass show mail/${address}";
          imap = {
            inherit host;
            port = 993;
          };
          smtp = {
            inherit host;
            port = 465;
          };
          aerc.enable = true;
          msmtp.enable = true;
        }
        // removeAttrs args [
          "address"
          "host"
          "realName"
        ];
    in
    {
      # School account (LOGINEO NRW mail, the same server for IMAP and SMTP).
      gymhueck = mkAccount {
        primary = true;
        address = "michael.lehnen@gymhueck.de";
        host = "mail.nrw.schule";
        # The server calls the inbox INBOX (Home Manager's default is "Inbox");
        # Sent, Drafts, Trash match the defaults.
        folders.inbox = "INBOX";
      };
    };

  programs.aerc = {
    enable = true;
    extraConfig = {
      # Home Manager writes accounts.conf as a store symlink (not mode 600);
      # it holds no secret, the password comes from pass.
      general.unsafe-accounts-conf = true;
      ui = {
        timestamp-format = "2006-01-02 15:04";
        this-day-time-format = "15:04";
        sort = "-r date";
        threading-enabled = true;
      };
      viewer.pager = "less -Rc";
      compose = {
        editor = "nvim";
        address-book-cmd = "";
      };
      # Default filters (the html one runs w3m without network access; nixpkgs
      # bundles w3m and dante with aerc).
      filters = {
        "text/plain" = "colorize";
        "text/calendar" = "calendar";
        "message/delivery-status" = "colorize";
        "message/rfc822" = "colorize";
        "text/html" = "! html";
        ".headers" = "colorize";
      };
      openers = {
        "application/pdf" = "zathura";
        "image/*" = "xdg-open";
        "text/html" = "firefox";
      };
    };
  };

  programs.msmtp.enable = true;
  programs.mbsync.enable = true;

  # pass + GPG. The agent caches the key passphrase for 8 h, so aerc and
  # msmtp do not ask on every connection. pinentry-qt (themed via qt6ct)
  # instead of a curses pinentry, which would draw over aerc.
  programs.password-store = {
    enable = true;
    settings.PASSWORD_STORE_DIR = "${config.xdg.dataHome}/password-store";
  };
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
    defaultCacheTtl = 28800;
    maxCacheTtl = 28800;
  };
}
