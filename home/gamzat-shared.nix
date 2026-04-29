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

  home.file.".config/.kube" = {
    source = "${dotfiles}/.kube";
    recursive = true;
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
    ripgrep
    fzf

    #LSP
    clang
    nodejs
    unzip
    cargo
    rustc
    dioxus-cli
    # LSP Server direkt installieren
    lua-language-server
    nil # Nix LSP
    typescript-language-server
    rust-analyzer
    clang-tools # clangd für C/C++
    vscode-langservers-extracted # JSON, HTML, CSS LSPs

    # Applications
    bitwarden-desktop
    bitwarden-cli
    wezterm
    moonlight-qt
    copyq

    claude-code
    gemini-cli

    # Secrets management
    sops
    age

    kubectl

    # Custom scripts
    rebuild-script
  ];

  # Wezterm configuration from dotfiles
  home.file.".config/wezterm" = {
    source = "${dotfiles}/wezterm";
    recursive = true;
  };

  # sops-nix home-manager configuration
  sops = {
    age.keyFile = "/home/gamzat/.config/sops/age/key.txt";
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
