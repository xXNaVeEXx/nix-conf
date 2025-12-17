{
  config,
  pkgs,
  lib,
  dotfiles,
  osConfig,
  ...
}:

let
  quickshellConfigDir = ../modules/desktop/configs/quickshell;
in

{
  home.stateVersion = "25.11";

  # Wayland environment variables
  home.sessionVariables = {
    XDG_RUNTIME_DIR = "/run/user/1000";
    WAYLAND_DISPLAY = "wayland-0";
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Gamzat";
        email = "mukailov.g@gmail.com";
      };
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

  programs.fzf = {
    enable = true;
    enableZshIntegration = false; # Manual integration in .zshrc
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false; # Manual integration in .zshrc
  };

  # zsh is managed manually via dotfiles
  home.packages =
    with pkgs;
    [
      zsh
      bat
      eza
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
      copyq
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

  # Install TPM (Tmux Plugin Manager)
  home.file.".tmux/plugins/tpm" = {
    source = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tpm";
      rev = "v3.1.0";
      sha256 = "sha256-CeI9Wq6tHqV68woE11lIY4cLoNY8XWyXyMHTDmFKJKI=";
    };
    recursive = true;
  };

  # Create .config/zsh directory for history file
  home.file.".config/zsh/.keep".text = "";

  # Quickshell configuration for MangoWC
  home.file.".config/quickshell" = lib.mkIf osConfig.mySystem.desktop.mangowc {
    source = quickshellConfigDir;
    recursive = true;
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
}
