{ pkgs, dotfiles, ... }:

{
  imports = [
    ./options.nix
    ./modules/dotfiles-base.nix
    ./modules/tmux.nix
    ./modules/shell.nix
    ./modules/sops.nix
    ./modules/kube.nix
  ];

  home.stateVersion = "25.11";

  myHome = {
    sops = {
      enable = true;
      ageKeyFile = "~/.config/sops/age/key.txt";
    };
    kube.enable = true;
  };
}
