{ pkgs, dotfiles, ... }:

{
  home.stateVersion = "25.11";

  # Wayland environment variables for root
  home.sessionVariables = {
    XDG_RUNTIME_DIR = "/run/user/1000";
    WAYLAND_DISPLAY = "wayland-0";
  };

  home.file.".config/nvim" = {
    source = "${dotfiles}/nvim";
    recursive = true;
  };

  home.file.".config/.kube" = {
    source = "${dotfiles}/.kube";
    recursive = true;
  };

  # Gleiche Zsh-Config wie gamzat
  home.file.".zshrc" = {
    source = "${dotfiles}/zsh/.zshrc";
  };

  home.file.".p10k.zsh" = {
    source = "${dotfiles}/zsh/.p10k.zsh";
  };

  # Create .config/zsh directory for history file
  home.file.".config/zsh/.keep".text = "";

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

}
