{
  config,
  osConfig,
  pkgs,
  lib,
  dotfiles,
  ...
}:

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
    enableZshIntegration = false; # Manual integration in .zshrc
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false; # Manual integration in .zshrc
  };

  home.packages =
    with pkgs;
    [
      bat
      eza
      zsh
      go
      tmux
      lazygit
      nerd-fonts.gohufont
    ]
    ++ lib.optionals osConfig.mySystem.passwordManager.bitwarden [
      bitwarden-desktop
      bitwarden-cli
    ]
    ++ lib.optionals osConfig.mySystem.terminal.wezterm [
      wezterm
    ]
    ++ lib.optionals osConfig.mySystem.streaming.moonlight [
      moonlight-qt
    ]
    ++ lib.optionals osConfig.mySystem.clipboard.copyq [
      maccy
    ];

  # Wezterm configuration from dotfiles
  home.file.".config/wezterm" = lib.mkIf osConfig.mySystem.terminal.wezterm {
    source = "${dotfiles}/wezterm";
    recursive = true;
  };

  # Tmux configuration from dotfiles
  home.file.".tmux.conf" = {
    source = "${dotfiles}/tmux/.tmux.conf";
  };

  # Create .config/zsh directory for history file
  home.file.".config/zsh/.keep".text = "";
}
