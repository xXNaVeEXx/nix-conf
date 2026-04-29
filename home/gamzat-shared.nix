{ pkgs, ... }:

let
  rebuild-script = import ../lib/rebuild-script.nix { inherit pkgs; };
in

{
  imports = [
    ./modules
    ./identities/gamzat.nix
    ./profiles/desktop-apps.nix
  ];

  home.username = "gamzat";
  home.homeDirectory = "/home/gamzat";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  myHome = {
    dev.enable = true;
    kube.enable = true;
  };

  # Per-machine extras beyond the dev base
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
