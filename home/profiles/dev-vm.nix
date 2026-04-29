{ pkgs, ... }:

let
  rebuild-script = import ../../lib/rebuild-script.nix { inherit pkgs; };
in

{
  imports = [ ./desktop-apps.nix ];

  myHome.dev.enable = true;

  home.packages = with pkgs; [
    git
    ripgrep
    libsForQt5.qt5.qtdeclarative # QML
    claude-code
    opencode
    rebuild-script
  ];
}
