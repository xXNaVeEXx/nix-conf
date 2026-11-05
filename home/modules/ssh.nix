{ config, lib, ... }:

let
  cfg = config.myHome.identity;
in

{
  programs.ssh = lib.mkIf (cfg.sshKey != null) {
    enable = true;
    enableDefaultConfig = false;
    # Privaten Key global anbieten: Root-Logins per IP (VPS) ohne eigenen Host-Block
    # bekommen dann Key-Auth statt Passwort-Fallback. settings."*" wird von HM
    # als letzter Host-*-Block gerendert, konkrete matchBlocks behalten Priorität.
    settings."*" = lib.optionalAttrs (cfg.privateSshKey != null) {
      identityFile = [ cfg.privateSshKey ];
      addKeysToAgent = "yes";
    };
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
    } // lib.optionalAttrs (cfg.privateSshKey != null) {
      # Alias für private Repos: gleicher GitHub-Host, zweiter Account-Key.
      # Remote-URLs dann git@github-navee:owner/repo.git.
      "github-navee" = {
        hostname = "github.com";
        user = "git";
        identityFile = cfg.privateSshKey;
      };
    };
  };
}
