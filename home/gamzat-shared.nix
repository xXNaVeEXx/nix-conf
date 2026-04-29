{ pkgs, ... }:

{
  imports = [
    ./modules
    ./identities/gamzat.nix
    ./profiles/dev-vm.nix
  ];

  home.username = "gamzat";
  home.homeDirectory = "/home/gamzat";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Per-machine extras beyond the dev base
  home.packages = with pkgs; [
    dioxus-cli
  ];
}
