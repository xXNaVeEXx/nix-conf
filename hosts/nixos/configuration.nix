# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  rebuild-script = pkgs.writeScriptBin "rebuild" ''
    #!/usr/bin/env bash

    # Find nix-config directory
    if [ -d /etc/nixos ]; then
      CONFIG_DIR="/etc/nixos"
    elif [ -d "$HOME/nix-config" ]; then
      CONFIG_DIR="$HOME/nix-config"
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
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    ../../options.nix

    ../../modules/desktop/gnome.nix
    ../../modules/desktop/pantheon.nix
    ../../modules/desktop/mangowc.nix
    ../../modules/gaming/steam.nix
    ../../users.nix
    ../../modules/networking.nix
    ../../modules/services.nix
    ../../modules/browser/brave.nix
    ../../modules/networking/tailscale.nix
  ];

  # activate flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  mySystem = {

    networking.tailscale = true;

    desktop = {
      enable = true;
      gnome = true;
      pantheon = false;
      mangowc = true;
      bar = "quickshell"; # Options: "waybar" or "quickshell"
    };

    gaming.steam = true;
    streaming.sunshine = true;
    streaming.moonlight = true;
    browser.brave = true;
    passwordManager.bitwarden = true;
    terminal.wezterm = true;
    clipboard.copyq = true;

  };

  nixpkgs.config.allowUnfree = true;

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;
  boot.kernelModules = [ "uinput" ];

  # Virtio GPU Support for proxmox
  boot.initrd.kernelModules = [ "virtio_gpu" ];
  hardware.graphics.enable = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "de_DE.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Configure keymap in X11 Keyboard
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "de";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire. Audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Install firefox.
  programs.firefox.enable = true;

  programs.zsh.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    rustdesk

    git
    neovim
    ripgrep
    tmux
    fzf

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
    claude-code

    # bash scripts
    rebuild-script
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  virtualisation.docker.enable = true;

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
