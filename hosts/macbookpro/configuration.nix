{ config, pkgs, ... }:

{
  imports = [
    ../../options.nix
    ../../modules/common
    ../../modules/networking/tailscale.nix
  ];

  mySystem = {
    networking.tailscale = true;
    passwordManager.bitwarden = true;
    terminal.wezterm = true;
    streaming.moonlight = true;
    clipboard.copyq = true;
  };

  # sops-nix configuration
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/Users/gamzat/.config/sops/age/key.txt";
  };

  nix.enable = false;

  nix.settings.trusted-users = [
    "root"
    "gamzat"
  ];

  system.primaryUser = "gamzat";

  environment.systemPackages = with pkgs; [
    # General utilities — useful for sudo workflows; dev tooling is installed at user level
    git
    neovim
    wget
    curl
    htop
    ripgrep
    fd
    fzf
    jq
    tmux
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

          "docker"

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
