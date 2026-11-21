{ lib, vars, ... }:

let
  # Public credentials of the FIDO2 keys (key handle + public key, no secret),
  # copied from the main repo ~/nixos (common/u2f_keys, written there by
  # `yubikey-registrieren`). Format: one line "<user>:<key 1>:<key 2>".
  keys = lib.trim (builtins.readFile ./u2f_keys);
in
{
  # FIDO2 security key (YubiKey) as an alternative to the password: on a
  # foreign PC it is the safe second way in (a fingerprint would have to be
  # enrolled on that PC's reader). Touch only, no PIN; the password always
  # remains as fallback. LUKS is NOT unlocked with the key: the passphrase also
  # unlocks the keyring (pam_fde_boot_pw, nixos-mango/configuration.nix).
  security.pam.u2f = {
    enable = true;
    control = "sufficient"; # touch alone is enough; NixOS orders u2f before fprintd
    settings = {
      cue = true; # "Please touch the device." in sudo/tuigreet
      nouserok = true; # no registered key: skip silently, go on to fprintd/password
      # Fixed origin, the same as in the main repo: the registration is valid
      # on every stick and on the SSD (the default pam://<hostname> differs).
      origin = vars.yubikeyOrigin;
      appid = vars.yubikeyOrigin;
      authfile = builtins.toFile "u2f_keys" (keys + "\n");
    };
  };
  # u2fAuth defaults to true for every PAM service once enabled; it covers
  # sudo, su, polkit-1, greetd (tuigreet after a logout) and login (also the
  # Noctalia lock screen, which needs lockscreen.allow_empty_password: Enter
  # with an empty field, then touch the key; nixos-mango/desktop.nix).
}
