{
  lib,
  pkgs,
  config,
  inputs,
  vars,
  ...
}:
let
  # Cursor theme and size, defined once here (nixbox.cursor) and read back by
  # Home Manager (./desktop.nix) via osConfig.
  cursorTheme = config.nixbox.cursor.theme;
in
{
  # The generated hardware-configuration.nix is added by the flake.
  imports = [
    inputs.mango.nixosModules.mango
    ../common/base.nix
    ../common/hardware-portable.nix
  ];

  # --- desktop ---
  # Declared in an explicit `options` because this module mixes option
  # declarations with configuration attributes; set once here, read back by
  # ./desktop.nix (osConfig) and in the session variables below.
  options.nixbox.cursor = {
    theme = lib.mkOption {
      type = lib.types.str;
      description = "Cursor theme name (installed below).";
    };
    size = lib.mkOption {
      type = lib.types.ints.positive;
      description = "Cursor size in pixels.";
    };
  };

  config = {
    # --- Mango specific: the Noctalia binary cache (avoids compiling the shell) ---
    nix.settings = {
      extra-substituters = [ "https://noctalia.cachix.org" ];
      extra-trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };

    programs.mango.enable = true; # session entry, portals, polkit, Xwayland
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-wlr
      ];
    };
    nixbox.cursor = {
      theme = "Breeze_Hacked";
      size = 48;
    };
    environment.sessionVariables = {
      QT_QPA_PLATFORMTHEME = "qt6ct";
      GTK_THEME = "adw-gtk3-dark"; # adw-gtk3 is installed below
      XCURSOR_THEME = cursorTheme;
      XCURSOR_SIZE = toString config.nixbox.cursor.size;
      XCURSOR_PATH = [ "/run/current-system/sw/share/icons" ];
    };
    environment.systemPackages = with pkgs; [
      adw-gtk3
      breeze-hacked-cursor-theme
      xwayland
    ];

    # --- login: one password, no login screen at boot ---
    # 1. You type the disk (LUKS) passphrase at boot.
    # 2. greetd logs the user in automatically (initial_session, boot only) and
    #    starts Mango.
    # 3. The same passphrase is handed to gnome-keyring (pam_fde_boot_pw), so the
    #    keyring (VSCodium, Chromium, gh) is unlocked without a second prompt.
    # 4. The Noctalia lock screen uses the same password, or the YubiKey.
    # After a logout or compositor crash greetd shows tuigreet and asks for
    #    the password: an autologin there would hand an unlocked session to
    #    anyone who can crash the compositor of a locked laptop.
    services.greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = "mango";
          inherit (vars) user;
        };
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd mango";
          user = "greeter";
        };
      };
    };
    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      KeyringMode = lib.mkForce "inherit";
    };
    systemd.services."getty@tty1".enable = false;
    systemd.services."autovt@tty1".enable = false;

    # Secret Service for VSCodium (Copilot/Claude sign-in), Chromium and gh;
    # without it they fall back to weakly protected files or keep asking.
    services.gnome.gnome-keyring.enable = true;
    # greetd includes login, which would otherwise start gnome-keyring before the
    # LUKS key is injected. Handle it in greetd's own session stack instead.
    security.pam.services.login.enableGnomeKeyring = lib.mkForce false;
    security.pam.services.greetd.rules.session = {
      fde_boot_pw = {
        order = 12600;
        control = "optional";
        modulePath = "${pkgs.pam_fde_boot_pw}/lib/security/pam_fde_boot_pw.so";
        args = [ "inject_for=gkr" ];
      };
      gnome_keyring = {
        order = 12700;
        control = "optional";
        modulePath = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
        args = [ "auto_start" ];
      };
    };
  };
}
