{ pkgs, ... }:

{
  home.stateVersion = "25.11";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  home.file.".config/nvim" = {
    source =
      builtins.fetchGit {
        url = "https://github.com/xXNaVeEXx/dotfiles";
        ref = "main";
      }
      + "/nvim";
    recursive = true;
  };

  programs.bash.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/mydevkey";
      };
    };
  };
}
