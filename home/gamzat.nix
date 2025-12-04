{
  config,
  pkgs,
  dotfiles,
  ...
}:

{
  home.stateVersion = "25.11";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.git = {
    enable = true;
    userName = "Gamzat";
    userEmail = "mukailov.g@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  home.file.".config/nvim" = {
    source = "${dotfiles}/nvim";
    recursive = true;
  };

  home.file.".p10k.zsh" = {
    source = "${dotfiles}/zsh/.p10k.zsh";
  };

  home.file.".zshrc" = {
    source = "${dotfiles}/zsh/.zshrc";
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
