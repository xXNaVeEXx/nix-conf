{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = {
    # Sunshine nur wenn aktiviert
    services.sunshine = lib.mkIf config.mySystem.streaming.sunshine {
      enable = true;
      openFirewall = true;
      capSysAdmin = true;
    };

    services.udev.extraRules = lib.mkIf config.mySystem.streaming.sunshine ''
      KERNEL=="uinput", GROUP="input", MODE="0660"
    '';

    boot.kernelModules = lib.mkIf config.mySystem.streaming.sunshine [ "uinput" ];

    # Basis-Services (immer aktiv)
    services.openssh.enable = true;
    services.tailscale.enable = true;
    services.printing.enable = true;
  };
}
