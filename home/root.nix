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

  home.sessionVariables = {
    XDG_RUNTIME_DIR = "/run/user/1000";
    WAYLAND_DISPLAY = "wayland-0";
  };

  myHome = {
    sops = {
      enable = true;
      ageKeyFile = "~/.config/sops/age/key.txt";
    };
    kube.enable = true;
  };
}
