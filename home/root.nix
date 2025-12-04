{ pkgs, dotfiles, ... }:

{
  home.stateVersion = "25.11";

  home.file.".config/nvim" = {
    source = "${dotfiles}/nvim";
    recursive = true;
  };
}
