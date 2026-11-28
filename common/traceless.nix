{ lib, pkgs, ... }:

{
  # The stick boots on PCs that are not ours (school PCs, in an emergency a
  # teacher's PC). Nothing on such a PC may change, and nothing may show that
  # the stick was booted there: no firmware variables, no TPM objects, no
  # clock change, no mounted internal disk. Everything below only touches the
  # stick itself. What remains outside our control (the firmware's own boot
  # menu bookkeeping, network logs) is listed in docs/tips/after-install.md.

  # --- firmware (EFI variables in the PC's NVRAM) ---
  # No boot entry in the PC's firmware; the firmware finds the stick through
  # the removable-media path EFI/BOOT/BOOTX64.EFI (bootctl --variables=no).
  boot.loader.efi.canTouchEfiVariables = false;
  # systemd-boot-random-seed.service runs `bootctl random-seed` at every boot,
  # which stores a persistent "system token" (LoaderSystemToken) in the NVRAM
  # of every PC the stick boots on. The kernel still seeds its entropy pool
  # from the CPU and the stick's own random seed.
  # systemd-pstore.service archives and then deletes crash records from
  # /sys/fs/pstore (on EFI: firmware variables, possibly the host system's).
  # enable = false masks them (a link to /dev/null), so nothing starts them.
  systemd.services.systemd-boot-random-seed.enable = false;
  systemd.services.systemd-pstore.enable = false;
  # The kernel would write its own oops/panic log into EFI variables (efi_pstore).
  boot.kernelParams = [ "efi_pstore.pstore_disable=1" ];
  # Belt and braces: once the system is up, the EFI variables are read-only,
  # so no program (fwupd, efibootmgr, systemctl reboot --firmware-setup, ...)
  # can write to the PC's firmware. Reading still works (bootctl status).
  # efi-traces (scripts/) remounts it read-write only for its own --remove.
  systemd.services.efivars-readonly = {
    description = "Make the EFI variables read-only (never write to a host PC's firmware)";
    wantedBy = [ "sysinit.target" ];
    before = [ "sysinit.target" ];
    after = [ "sys-firmware-efi-efivars.mount" ];
    unitConfig = {
      DefaultDependencies = false;
      ConditionPathIsMountPoint = "/sys/firmware/efi/efivars";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.util-linux}/bin/mount -o remount,ro /sys/firmware/efi/efivars";
    };
  };

  # --- TPM ---
  # systemd-tpm2-setup creates a persistent storage root key in the PC's TPM
  # (and an NvPCR) if there is none: an object that stays in the host's TPM.
  # Nothing here uses the TPM (LUKS uses the passphrase, the YubiKey is FIDO2).
  systemd.tpm2.enable = false;
  boot.initrd.systemd.tpm2.enable = false;
  # Asks the firmware (PPI) to clear the TPM at the next boot; only wanted by
  # factory-reset.target, never needed here.
  systemd.services.systemd-tpm2-clear.enable = false;

  # --- hardware clock (CMOS RTC of the PC) ---
  # The clock is only read (time.hardwareClockInLocalTime in base.nix: the
  # Windows PCs keep local time). systemd-timesyncd would let the kernel copy
  # the system time into the RTC every 11 minutes; chrony without `rtcsync`
  # keeps the kernel flag that prevents this (and without rtcfile/rtcautotrim
  # never touches the RTC itself). A wrong PC clock stays wrong.
  services.chrony = {
    enable = true;
    enableRTCTrimming = false;
    # Step the clock whenever it is off by more than 1 s, not only in the
    # first 3 updates (the default `makestep 0.1 3`): after a suspend on a PC
    # whose RTC keeps local time the clock came back 1 h fast (2026-11-28),
    # and slewing an hour takes about 12 h. The option's `limit` only takes
    # positive numbers, hence extraConfig for -1 (= always).
    makestep.enable = false;
    extraConfig = "makestep 1 -1";
  };

  # --- network ---
  # DHCP requests do not announce the hostname (the school's DHCP log would
  # show "nixstick" instead of the PC's Windows name).
  networking.networkmanager.settings.connection = {
    "ipv4.dhcp-send-hostname" = false;
    "ipv6.dhcp-send-hostname" = false;
  };
  # Wi-Fi: a stable MAC address per network, derived from the stick (not the
  # PC's own address). Ethernet keeps the PC's address: school networks may
  # filter by MAC, and Windows uses the same one there.
  networking.networkmanager.wifi.macAddress = "stable-ssid";

  # --- internal disks of the PC ---
  # Never mount, check or show them: udisks (file managers, udiskie) ignores
  # SATA and NVMe disks. USB drives (also the stick itself) and SD cards stay
  # visible. `sudo mount` still works if it is ever needed (read-only: -o ro).
  # USB-SATA docks report ID_BUS=ata too; ID_PATH contains "-usb-" for them,
  # so they are not ignored (otherwise udiskie shows no passphrase dialog).
  services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{ID_BUS}=="ata|nvme", ENV{ID_PATH}!="*-usb-*", ENV{UDISKS_IGNORE}="1", ENV{UDISKS_AUTO}="0"
  '';

  # --- what would write to the PC on its own ---
  # Battery charge limits live in the laptop's embedded controller and stay
  # after a reboot; there is deliberately no option for them here.
  # Fingerprint readers with on-chip storage keep enrolled prints on the
  # reader itself: enroll only on own devices (docs/tips/after-install.md).
  services.fwupd.enable = lib.mkForce false;
}
