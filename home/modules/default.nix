{
  imports = [
    ../options.nix

    ./dotfiles-base.nix
    ./tmux.nix
    ./shell.nix
    ./programs.nix

    ./git.nix
    ./ssh.nix
    ./sops.nix
    ./dev.nix
    ./apps.nix
    ./kube.nix
  ];
}
