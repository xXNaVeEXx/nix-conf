{ pkgs, ... }:

{
  home.stateVersion = "25.11";

  home.file.".config/nvim" = {
    source =
      builtins.fetchGit {
        url = "https://github.com/xXNaVeEXx/dotfiles";
        ref = "main";
      }
      + "/nvim";
    recursive = true;
  };
}
