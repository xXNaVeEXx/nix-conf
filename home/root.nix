{ pkgs, dotfiles, ... }:

{
  imports = [
    ./modules/dotfiles-base.nix
    ./modules/tmux.nix
  ];

  home.stateVersion = "25.11";

  # Wayland environment variables for root
  home.sessionVariables = {
    XDG_RUNTIME_DIR = "/run/user/1000";
    WAYLAND_DISPLAY = "wayland-0";
  };

  home.file.".config/.kube" = {
    source = "${dotfiles}/.kube";
    recursive = true;
  };

  # zsh is managed manually via dotfiles
  home.packages = with pkgs; [
    zsh
    bat
    eza
    tmux
    lazygit
    nerd-fonts.gohufont

    sops
    age

  ];

  # sops-nix home-manager configuration
  sops = {
    age.keyFile = "~/.config/sops/age/key.txt";
    defaultSopsFile = ../../secrets/secrets.yaml;

    # Example secrets - uncomment and customize as needed
    # secrets.example-key = {
    #   path = "%r/example-secret";
    # };
  };

  # sops configuration for manual encryption/decryption
  home.file.".config/sops/.sops.yaml".text = ''
    keys:
      - &admin_key age14pdqf7sl4sltz442mvfyafchvxn5wvv988gv6enhhrmyx3ch5qfs5y6atl

    creation_rules:
      # Kubernetes configs
      - path_regex: \.kube/.*
        age: *admin_key

      # All other files
      - path_regex: .*
        age: *admin_key
  '';

}
