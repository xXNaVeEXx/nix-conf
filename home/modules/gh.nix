{ config, lib, ... }:

{
  # identity.sshKey targets github.com, so keep gh on SSH as well.
  programs.gh = lib.mkIf config.myHome.apps.gh {
    enable = true;
    settings.git_protocol = "ssh";
  };
}
