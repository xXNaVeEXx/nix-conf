{
  config,
  osConfig,
  pkgs,
  lib,
  dotfiles,
  ...
}:

{
  home.stateVersion = "25.11";
  home.username = "gamzat";
  home.homeDirectory = "/Users/gamzat";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  home.file.".config/nvim" = {
    source = "${dotfiles}/nvim";
    recursive = true;
  };

  # Zsh mit deinen Dotfiles
  home.file.".zshrc" = {
    source = "${dotfiles}/zsh/.zshrc";
  };

  home.file.".config/.kube" = {
    source = "${dotfiles}/.kube";
    recursive = true;
  };

  home.file.".p10k.zsh" = {
    source = "${dotfiles}/zsh/.p10k.zsh";
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Gamzat";
        email = "mukailov.g@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };
      pull = {
        rebase = true;
      };
    };
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

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = false; # Manual integration in .zshrc
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false; # Manual integration in .zshrc
  };

  home.packages =
    with pkgs;
    [
      bat
      eza
      zsh
      go
      tmux
      lazygit
      nerd-fonts.gohufont

      kubectl

       sops
       age
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
      maccy
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

  # sops-nix home-manager configuration
  sops = {
    age.keyFile = "/Users/gamzat/.config/sops/age/key.txt";
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
