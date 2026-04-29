{ config, lib, dotfiles, ... }:

{
  home.file.".config/.kube" = lib.mkIf config.myHome.kube.enable {
    source = "${dotfiles}/.kube";
    recursive = true;
  };
}
