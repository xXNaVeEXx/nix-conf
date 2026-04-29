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

  home.username = "gamzat";
  home.homeDirectory = "/home/gamzat";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  myHome = {
    identity = {
      name = "Gamzat";
      email = "mukailov.g@gmail.com";
      sshKey = "~/.ssh/mydevkey";
    };
    sops = {
      enable = true;
      ageKeyFile = "/home/gamzat/.config/sops/age/key.txt";
    };
    dev.enable = true;
    apps = {
      bitwarden = true;
      wezterm = true;
      moonlight = true;
      clipboard = true;
    };
    kube.enable = true;
  };

  # Per-machine extras beyond the shared dev set
  home.packages = with pkgs; [
    ripgrep
    fzf
    dioxus-cli
    kubectl
    claude-code
    gemini-cli
    rebuild-script
  ];
}
