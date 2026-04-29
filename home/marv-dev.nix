{ ... }:

{
  imports = [
    ./modules
    ./profiles/dev-vm.nix
  ];

  home.username = "marv";
  home.homeDirectory = "/home/marv";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  myHome.identity = {
    name = "Marv";
    email = "Marv@gmail.com";
    sshKey = "~/.ssh/id_ed25519";
  };
}
