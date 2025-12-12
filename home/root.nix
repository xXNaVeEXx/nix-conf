{ pkgs, dotfiles, ... }:

{
  home.stateVersion = "25.11";

  home.file.".config/nvim" = {
    source = "${dotfiles}/nvim";
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
}
