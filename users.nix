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
    packages = with pkgs; [
      thunderbird
    ];
  };
}
