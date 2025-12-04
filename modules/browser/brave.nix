{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.mySystem.browser.brave {
    environment.systemPackages = [ pkgs.brave ];
  };
}
