{ config, ... }:

{
  myHome = {
    identity = {
      name = "Gamzat";
      email = "mukailov.g@gmail.com";
      sshKey = "~/.ssh/mydevkey";
    };
    sops = {
      enable = true;
      ageKeyFile = "${config.home.homeDirectory}/.config/sops/age/key.txt";
    };
  };
}
