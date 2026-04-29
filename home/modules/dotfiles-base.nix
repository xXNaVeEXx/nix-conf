{ dotfiles, ... }:

{
  home.file.".config/nvim" = {
    source = "${dotfiles}/nvim";
    recursive = true;
  };

  home.file.".zshrc" = {
    source = "${dotfiles}/zsh/.zshrc";
  };

  home.file.".p10k.zsh" = {
    source = "${dotfiles}/zsh/.p10k.zsh";
  };

  home.file.".config/zsh/.keep".text = "";
}
