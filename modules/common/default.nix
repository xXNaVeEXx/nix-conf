{ pkgs, ... }:

let
  rebuild-script = import ../../lib/rebuild-script.nix { inherit pkgs; };
in

{
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = [ rebuild-script ];
}
