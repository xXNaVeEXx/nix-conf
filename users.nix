{ pkgs, ... }:

{
  users.users.gamzat = {
    isNormalUser = true;
    description = "Gamzat";
    extraGroups = [
      "networkmanager"
      "wheel"
      "input" # for mouse input when streaming
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      thunderbird
    ];
  };

  users.users.root = {
    shell = pkgs.zsh; # Wenn root Zsh nutzen soll
  };
}
