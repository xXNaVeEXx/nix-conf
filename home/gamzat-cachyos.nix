{ pkgs, ... }:

let
  rebuild-script = import ../lib/rebuild-script.nix { inherit pkgs; };
in

{
  imports = [
    ./modules
    ./identities/gamzat.nix
    ./profiles/desktop-apps.nix
  ];

  home.username = "gamzat";
  home.homeDirectory = "/home/gamzat";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Non-NixOS: expose ~/.nix-profile/share (XDG_DATA_DIRS) to the Plasma
  # session via ~/.config/environment.d so KDE's launcher sees the .desktop files.
  targets.genericLinux.enable = true;
  # The .desktop files use bare Exec=/TryExec= names, so the session PATH needs the
  # profile too. systemd ignores PATH from environment.d, so set it in Plasma's
  # startup env scripts (sourced by startplasma before the session starts).
  home.file.".config/plasma-workspace/env/nix-profile-path.sh".text = ''
    export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
  '';

  myHome.pi.enable = true;

  home.packages = with pkgs; [
    claude-code
    opencode
    rebuild-script
  ];
}
