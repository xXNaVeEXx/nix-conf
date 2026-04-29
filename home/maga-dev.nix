{
  config,
  pkgs,
  lib,
  dotfiles,
  ...
}:

let
  rebuild-script = import ../lib/rebuild-script.nix { inherit pkgs; };
in

{
  imports = [
    ./modules/dotfiles-base.nix
    ./modules/tmux.nix
  ];

  home.username = "maga";
  home.homeDirectory = "/home/maga";
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
        name = "Magram";
        email = "magramzijaev@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
    };
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
  # Shared packages across all systems
  home.packages = with pkgs; [
    zsh
    bat
    eza
    tmux
    lazygit
    nerd-fonts.gohufont

    git
    ripgrep

    clang
    nodejs
    unzip
    cargo
    rustc
    # LSP Server direkt installieren
    lua-language-server
    nil # Nix LSP
    typescript-language-server
    rust-analyzer
    clang-tools # clangd für C/C++
    vscode-langservers-extracted # JSON, HTML, CSS LSPs
    libsForQt5.qt5.qtdeclarative # QML

    # Applications
    bitwarden-desktop
    bitwarden-cli
    wezterm
    moonlight-qt
    copyq

    claude-code
    opencode

    # Custom scripts
    rebuild-script
  ];

  # Wezterm configuration from dotfiles
  home.file.".config/wezterm" = {
    source = "${dotfiles}/wezterm";
    recursive = true;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };
}
