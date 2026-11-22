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
in
{
  # Printing, as in the main repo's common/printing.nix. Network only: nothing
  # here touches the host PC's hardware (common/traceless.nix).
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
    ];
    ensureDefaultPrinter = printer.name;
  };

  # Printer settings GUI.
  programs.system-config-printer.enable = true;
}
