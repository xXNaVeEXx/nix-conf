{ config, lib, ... }:

{
  services.tailscale.enable = lib.mkIf config.mySystem.networking.tailscale;
}
