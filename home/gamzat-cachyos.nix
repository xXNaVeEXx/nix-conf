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

  home.packages = with pkgs; [
    claude-code
    opencode
    rebuild-script
  ];
}
