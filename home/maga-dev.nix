{
  config,
  pkgs,
  lib,
  dotfiles,
  ...
}:

let
  rebuild-script = import ../lib/rebuild-script.nix { inherit pkgs; };
in

{
  imports = [ ./modules ];

  home.username = "maga";
  home.homeDirectory = "/home/maga";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  myHome = {
    identity = {
      name = "Magram";
      email = "magramzijaev@gmail.com";
      sshKey = "~/.ssh/id_ed25519";
    };
    dev.enable = true;
    apps = {
      bitwarden = true;
      wezterm = true;
      moonlight = true;
      clipboard = true;
    };
  };

  # Per-machine extras
  home.packages = with pkgs; [
    git
    ripgrep
    libsForQt5.qt5.qtdeclarative # QML
    claude-code
    opencode
    rebuild-script
  ];
}
