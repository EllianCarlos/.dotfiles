{ pkgs, ... }: {
  # Enable the CUPS service
  services.printing = {
    enable = true;
    drivers = [ pkgs.epson_201310w ]; # Replace with your specific driver if needed
  };

  # Enable network discovery (required for wireless printers)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
