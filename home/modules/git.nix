{ config, lib, ... }:

let
  cfg = config.myHome.identity;
  enabled = cfg.name != null && cfg.email != null;
in

{
  programs.git = lib.mkIf enabled {
    enable = true;
    settings = {
      user = {
        name = cfg.name;
        email = cfg.email;
      };
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
}
