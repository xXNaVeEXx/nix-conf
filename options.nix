{ config, lib, ... }:

{
  options.mySystem = {
    desktop = {
      enable = lib.mkEnableOption "desktop environment";
      gnome = lib.mkEnableOption "GNOME desktop";
      pantheon = lib.mkEnableOption "Pantheon desktop";
    };
    gaming = {
      steam = lib.mkEnableOption "Steam";
    };
    streaming = {
      sunshine = lib.mkEnableOption "Sunshine streaming server";
    };
    browser = {
      brave = lib.mkEnableOption "Brave Browser";
    };
  };
}
