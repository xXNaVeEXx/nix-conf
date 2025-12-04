{ config, pkgs, ... }:

{
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
  ];

  system.stateVersion = 5;

  system.defaults = {
    dock = {
      autohide = true;
      orientation = "bottom";
      show-recents = false;
      tilesize = 48;
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
    (nerdfonts.override {
      fonts = [
        "FiraCode"
        "JetBrainsMono"
        "Meslo"
      ];
    })
  ];

  programs.zsh.enable = true;

  users.users.gamzat = {
    name = "gamzat";
    home = "/Users/gamzat";
    shell = pkgs.zsh;
  };
}
