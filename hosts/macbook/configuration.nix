{ config, pkgs, ... }:

let
  rebuild-script = pkgs.writeScriptBin "rebuild" ''
    #!/usr/bin/env bash

    # Find nix-config directory
    if [ -d "$HOME/nix-config" ]; then
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
  imports = [
    ../../options.nix
  ];

  mySystem = {
    passwordManager.bitwarden = true;
    terminal.wezterm = true;
    streaming.moonlight = true;
    clipboard.copyq = true;
  };

  nix.enable = false;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "gamzat"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  system.primaryUser = "gamzat";

  environment.systemPackages = with pkgs; [
    git
    neovim
    nodejs
    typescript
    python3
    wget
    curl
    htop
    ripgrep
    fd
    fzf
    jq
    tmux
    lua-language-server
    nil
    typescript-language-server
    rust-analyzer
    clang-tools
    vscode-langservers-extracted
    claude-code

    # bash scripts
    rebuild-script
  ];

  system.stateVersion = 5;

  system.defaults = {
    dock = {
      autohide = true;
      orientation = "bottom";
      show-recents = false;
      tilesize = 48;
      persistent-apps = [
        "/Applications/Brave Browser.app"
        "/Users/gamzat/Applications/Home Manager Apps/WezTerm.app"
      ];
    };

    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      FXEnableExtensionChangeWarning = false;
    };

    NSGlobalDomain = {
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      AppleInterfaceStyle = "Dark";
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # Homebrew für GUI-Apps
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };

    casks = [
      "visual-studio-code"
      "iterm2"
      "rectangle"
      "firefox"
      "slack"
      "discord"
    ];
  };

  fonts.packages = with pkgs; [
    (nerd-fonts.fira-code)
    (nerd-fonts.jetbrains-mono)
    (nerd-fonts.meslo-lg)
  ];

  programs.zsh.enable = true;

  users.users.gamzat = {
    name = "gamzat";
    home = "/Users/gamzat";
    shell = pkgs.zsh;
    uid = 501;
  };
}
