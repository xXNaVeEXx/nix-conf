{ config, lib, ... }:

let
  cfg = config.myHome.identity;
in

{
  programs.ssh = lib.mkIf (cfg.sshKey != null) {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = cfg.sshKey;
      };
      "forgejo.gamzatlab.net" = {
        hostname = "forgejo.gamzatlab.net";
        user = "gamzat";
        identityFile = cfg.sshKey;
      };
    };
  };
}
