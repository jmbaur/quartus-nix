{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.programs.quartus-pro-programmer = {
    enable = lib.mkEnableOption "quartus-pro-programmer";
    package = lib.mkPackageOption pkgs "quartus-pro-programmer" { };
  };

  config = lib.mkIf config.programs.quartus-pro-programmer.enable {
    environment = {
      systemPackages = [ config.programs.quartus-pro-programmer.package ];
      profileRelativeSessionVariables.PATH = [ "/qprogrammer/quartus/bin" ];
      pathsToLink = [ "/qprogrammer" ];
    };

    users.groups.plugdev = { };

    services.udev.extraRules = ''
      # USB-Blaster
      SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6001", MODE="0666", GROUP="plugdev"
      SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6002", MODE="0666", GROUP="plugdev"
      SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6003", MODE="0666", GROUP="plugdev"

      # USB-Blaster II
      SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6010", MODE="0666", GROUP="plugdev"
      SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="0666", GROUP="plugdev"
    '';
  };
}
