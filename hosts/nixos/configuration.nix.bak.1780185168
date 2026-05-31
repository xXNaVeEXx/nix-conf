# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  # RustDesk wrapper to force X11/XWayland mode
  rustdesk-x11 = pkgs.symlinkJoin {
    name = "rustdesk-x11";
    paths = [ pkgs.rustdesk-flutter ]; # Try Flutter version
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/rustdesk \
        --set DISPLAY :0 \
        --unset WAYLAND_DISPLAY \
        --set GDK_BACKEND x11 \
        --set QT_QPA_PLATFORM xcb \
        --set SDL_VIDEODRIVER x11 \
        --set CLUTTER_BACKEND x11
    '';
  };
in

{
  #Automatic updating
  system.autoUpgrade.enable = true;
  system.autoUpgrade.dates = "weekly";

  # Automatic cleanup. Keep 30d of generations so a bad weekly
  # auto-upgrade still has rollback room.
  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 30d";
  nix.settings.auto-optimise-store = true;

  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    ../../options.nix

    ../../modules/common
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

  mySystem = {

    networking.tailscale = true;

    desktop = {
      enable = true;
      gnome = false; # Only use Mango session
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

    remote.wayvnc = true;
  };

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;
  boot.kernelModules = [
    "uinput"
    "br_netfilter"
    "overlay"
  ];

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

  # flatpak
  services.flatpak.enable = true;

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

  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    glibc
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    android-tools # adb for android emulation
    wayvnc # Native Wayland VNC server
    wl-clipboard
    wf-recorder # Screen recording for Wayland

    # General utilities — useful for sudo workflows; user-level installs are in home/
    git
    neovim
    ripgrep
    tmux
    fzf

    # OpenGL/Mesa packages for VM graphics
    mesa
    mesa.drivers
    libGL
    libGLU

    # nix cli
    nh
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  virtualisation.docker.enable = true;

  # k3s worker
  #
  # tokenFile is read at activation time. The file is provisioned out-of-band
  # — secrets/ is gitignored, so a fresh checkout starts empty. Drop the join
  # token into <repo>/secrets/k3s-token.key (mode 0400, root-owned) before
  # rebuilding, or k3s.service will fail to start.
  #
  # To move this under system-level sops-nix later:
  #   1. Add sops-nix.nixosModules.sops to the nixos module list in flake.nix
  #   2. Declare sops.defaultSopsFile + sops.age.keyFile (root-readable) here
  #   3. sops.secrets.k3s-token = { sopsFile = ../../secrets/secrets.yaml; }
  #   4. tokenFile = config.sops.secrets.k3s-token.path
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://k3s-controller:6443";
    tokenFile = "/etc/nixos/secrets/k3s-token.key";

    extraFlags = [
      "--node-name ${config.networking.hostName}"
    ];
  };

  # Sysctl settings for Kubernetes
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
  };

  # List services that you want to enable:

  # Open ports in the firewall.
  networking.firewall = {
    allowedTCPPorts = [
      5900
      10250
    ]; # Wayvnc VNC port, Kubelet
    allowedUDPPorts = [ 8472 ]; # Flannel VXLAN (if using flannel)
  };
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
