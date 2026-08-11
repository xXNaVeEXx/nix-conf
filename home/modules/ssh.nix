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
      # Git-Zugriff auf Forgejo: NodePort 30022, nur auf .82 erreichbar
      "forgejo-git" = {
        hostname = "192.168.178.82";
        port = 30022;
        user = "git";
        identityFile = cfg.sshKey;
      };
    };
  };
}
