{ pkgs, ... }:

{
  # Hardware part for a system that lives on a USB stick and boots on any
  # x86_64 UEFI PC (Intel or AMD). The generated hardware-configuration.nix only
  # knows the machine the installer ran on; everything another PC may need is
  # added here. Shared system settings live in base.nix. No battery charge
  # limits: they would stay in a foreign laptop's controller (traceless.nix).

  config = {
    # --- boot from whatever controller the stick is plugged into ---
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "ehci_pci"
      "uas"
      "usb_storage"
      "usbhid"
      "hid_generic"
      "sd_mod"
      "thunderbolt"
      "nvme"
      "ahci"
      # Early KMS: thunderbolt loads here (TB disks) and tears down the
      # firmware's DP tunnel; with the GPU driver loaded at the same time, a
      # Thunderbolt monitor gets its new DP tunnel right away (a late i915
      # once left the monitor black until reboot, main repo 2026-11-23). udev
      # loads it only on Intel GPUs; amdgpu stays out (its firmware would bloat
      # every initrd on the ESP).
      "i915"
    ];
    boot.kernelModules = [
      "kvm-intel"
      "kvm-amd"
    ];

    # --- firmware and microcode for Intel and AMD (only the matching one loads) ---
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;
    hardware.cpu.amd.updateMicrocode = true;
    hardware.firmware = [ pkgs.sof-firmware ]; # Intel laptop audio

    # --- graphics: Mesa (AMD/Intel/nouveau) from hardware.graphics; Intel video
    #     decoding on top. No LIBVA_DRIVER_NAME: libva picks iHD or radeonsi
    #     per machine.
    hardware.graphics.extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt # QSV on Gen12+ (Tiger Lake and newer)
    ];

    # Fingerprint readers where present (fprintd is D-Bus activated, idle otherwise).
    services.fprintd.enable = true;
  };
}
