{ ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.bash.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false;
  };
}
