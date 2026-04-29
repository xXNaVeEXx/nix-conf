{
  config,
  osConfig,
  pkgs,
  lib,
  dotfiles,
  ...
}:

{
  imports = [ ./modules ];

  home.stateVersion = "25.11";
  home.username = "gamzat";
  home.homeDirectory = "/Users/gamzat";

  myHome = {
    identity = {
      name = "Gamzat";
      email = "mukailov.g@gmail.com";
      sshKey = "~/.ssh/mydevkey";
    };
    sops = {
      enable = true;
      ageKeyFile = "/Users/gamzat/.config/sops/age/key.txt";
    };
    apps = {
      bitwarden = osConfig.mySystem.passwordManager.bitwarden;
      wezterm = osConfig.mySystem.terminal.wezterm;
      moonlight = osConfig.mySystem.streaming.moonlight;
      clipboard = osConfig.mySystem.clipboard.copyq;
    };
    kube.enable = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs; [
    go
    kubectl
  ];
}
