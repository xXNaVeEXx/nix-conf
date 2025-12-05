{
  config,
  pkgs,
  lib,
  dotfiles,
  osConfig,
  ...
}:

{
  home.stateVersion = "25.11";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.git = {
    enable = true;
    userName = "Gamzat";
    userEmail = "mukailov.g@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  home.file.".config/nvim" = {
    source = "${dotfiles}/nvim";
    recursive = true;
  };

  home.file.".p10k.zsh" = {
    source = "${dotfiles}/zsh/.p10k.zsh";
  };

  home.file.".zshrc" = {
    source = "${dotfiles}/zsh/.zshrc";
  };

  programs.bash.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;  # Manual integration in .zshrc
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false;  # Manual integration in .zshrc
  };

  # zsh is managed manually via dotfiles
  home.packages = with pkgs; [
    zsh
    bat
    eza
    tmux
    lazygit
    nerd-fonts.gohufont
  ] ++ lib.optionals osConfig.mySystem.passwordManager.bitwarden [
    bitwarden-desktop
    bitwarden-cli
  ] ++ lib.optionals osConfig.mySystem.terminal.wezterm [
    wezterm
  ] ++ lib.optionals osConfig.mySystem.streaming.moonlight [
    moonlight-qt
  ] ++ lib.optionals osConfig.mySystem.clipboard.copyq [
    copyq
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

  home.file.".tmux" = {
    source = "${dotfiles}/tmux/.tmux";
    recursive = true;
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
}
