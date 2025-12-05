{ config, lib, ... }:

{
  config = lib.mkIf config.mySystem.networking.tailscale {
    services.tailscale.enable = true;
  };
}
