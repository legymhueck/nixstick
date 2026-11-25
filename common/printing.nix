{ pkgs, ... }:

let
  # Copied from the main repo (~/GitHub/nixos_full/nixos, common/devices.toml);
  # change it there too. The printer is on the home LAN only.
  printer = {
    name = "Kyocera_FS-3820N";
    description = "Kyocera FS-3820N";
    location = "LAN";
    ip = "192.168.2.52";
    port = 9100;
    model = "foomatic-db-ppds/Kyocera-FS-3820N-Postscript-Kyocera.ppd.gz";
    page_size = "A4";
  };

  # OKI ES4132 (mono A4 laser, duplex; OKI's Executive twin of the B412dn).
  # No own PPD in nixpkgs; it speaks PCL 6, so the generic PCL 6 driver.
  # Two queues for the same printer: on USB (URI with its serial, so only this
  # printer matches) and on the LAN at 192.168.0.103 (raw port 9100).
  oki = {
    description = "OKI ES4132";
    model = "foomatic-db-ppds/Generic-PCL_6_PCL_XL_Printer-pxlmono.ppd.gz";
    ppdOptions.PageSize = "A4";
  };
in
{
  # Printing, as in the main repo's common/printing.nix. Network and USB printers;
  # nothing here touches the host PC's hardware (common/traceless.nix).
  services.printing = {
    enable = true;
    drivers = [ pkgs.foomatic-db-ppds ]; # Kyocera's own PostScript PPDs
  };
  # The printer neither announces itself via mDNS nor speaks driverless IPP,
  # so the queue is created here (on every start of cups.service).
  hardware.printers = {
    ensurePrinters = [
      {
        inherit (printer)
          name
          description
          location
          model
          ;
        deviceUri = "socket://${printer.ip}:${toString printer.port}";
        ppdOptions.PageSize = printer.page_size;
      }
      (
        oki
        // {
          name = "OKI_ES4132_USB";
          location = "USB";
          deviceUri = "usb://OKI%20DATA%20CORP/ES4132?serial=AK74020371";
        }
      )
      (
        oki
        // {
          name = "OKI_ES4132_LAN";
          location = "LAN 192.168.0.103";
          deviceUri = "socket://192.168.0.103:9100";
        }
      )
    ];
    ensureDefaultPrinter = printer.name;
  };

  # Printer settings GUI.
  programs.system-config-printer.enable = true;
}
