{ pkgs, dotfiles, ... }:

{
  imports = [
    ./modules
    ./profiles/dev-vm.nix
  ];

  home.username = "maga";
  home.homeDirectory = "/home/maga";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  myHome.identity = {
    name = "Maga";
    email = "magramzijaev@gmail.com";
    sshKey = "~/.ssh/id_ed25519";
  };

  # Additional packages unique to this config
  home.packages = with pkgs; [
    code-cursor
  ];
}
