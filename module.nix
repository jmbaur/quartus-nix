{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf mkPackageOption;

  cfg = config.programs.quartus-pro-programmer;
in
{
  options.programs.quartus-pro-programmer = {
    enable = mkEnableOption "quartus-pro-programmer";
    package = mkPackageOption pkgs "quartus-pro-programmer-latest" { };

    jtagd.enable = mkEnableOption "jtagd server";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

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

    systemd.services.jtagd = mkIf cfg.jtagd.enable {
      serviceConfig = {
        DynamicUser = true;
        ExecStart = toString [
          (lib.getExe' cfg.package "jtagd")
          "--foreground"
          "--debug"
        ];
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
