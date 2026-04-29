{ ... }:

{
  imports = [
    ./modules
    ./profiles/dev-vm.nix
  ];

  home.username = "maga";
  home.homeDirectory = "/home/maga";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  myHome.identity = {
    name = "Magram";
    email = "magramzijaev@gmail.com";
    sshKey = "~/.ssh/id_ed25519";
  };
}
