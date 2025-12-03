{ config, lib, ... }:

{
  config = lib.mkIf config.mySystem.gaming.steam {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
  };
}
