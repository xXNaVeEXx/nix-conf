{ pkgs, dotfiles, ... }:

{
  home.stateVersion = "25.11";
  home.username = "gamzat";
  home.homeDirectory = "/Users/gamzat";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  home.file.".config/nvim" = {
    source = "${dotfiles}/nvim";
    recursive = true;
  };

  # Zsh mit deinen Dotfiles
  home.file.".zshrc" = {
    source = "${dotfiles}/zsh/.zshrc";
  };

  home.file.".p10k.zsh" = {
    source = "${dotfiles}/zsh/.p10k.zsh";
  };

   programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Gamzat";
        email = "mukailov.g@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };
      pull = {
        rebase = true;
      };
    };
  };

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

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;  # Manual integration in .zshrc
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false;  # Manual integration in .zshrc
  };

  home.packages = with pkgs; [
    bat
    eza
    zsh
    go
    wezterm
    tmux
    nerd-fonts.gohufont
  ];

  # Wezterm configuration from dotfiles
  home.file.".config/wezterm" = {
    source = "${dotfiles}/wezterm";
    recursive = true;
  };

  # Tmux configuration from dotfiles
  home.file.".tmux.conf" = {
    source = "${dotfiles}/tmux/.tmux.conf";
  };

  home.file.".tmux" = {
    source = "${dotfiles}/tmux/.tmux";
    recursive = true;
  };
}
