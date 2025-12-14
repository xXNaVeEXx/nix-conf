{
  config,
  pkgs,
  lib,
  dotfiles,
  ...
}:

let
  # Create rebuild script that can be run from anywhere
  rebuild-script = pkgs.writeScriptBin "rebuild" ''
    #!/usr/bin/env bash

    # Find nix-config directory
    if [ -d "$HOME/projects/nix-conf" ]; then
      CONFIG_DIR="$HOME/projects/nix-conf"
    elif [ -d "$HOME/nix-config" ]; then
      CONFIG_DIR="$HOME/nix-config"
    elif [ -d /etc/nixos ]; then
      CONFIG_DIR="/etc/nixos"
    else
      echo "Error: Could not find nix-config directory"
      exit 1
    fi

    cd "$CONFIG_DIR"
    exec ${pkgs.bash}/bin/bash "$CONFIG_DIR/rebuild.sh" "$@"
  '';
in

{
  home.username = "gamzat";
  home.homeDirectory = "/home/gamzat";
  home.stateVersion = "25.11";

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

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
  # Enable all packages that are enabled in NixOS configuration
  home.packages = with pkgs; [
    zsh
    bat
    eza
    tmux
    lazygit
    nerd-fonts.gohufont

    # CachyOS specific packages (matching NixOS mySystem settings)
    bitwarden-desktop
    bitwarden-cli
    wezterm
    moonlight-qt
    copyq

    claude-code

    # Custom scripts
    rebuild-script
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

  # Create .config/zsh directory for history file
  home.file.".config/zsh/.keep".text = "";

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
