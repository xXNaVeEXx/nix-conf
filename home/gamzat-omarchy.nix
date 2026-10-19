{ pkgs, ... }:

let
  rebuild-script = import ../lib/rebuild-script.nix { inherit pkgs; };
in

{
  imports = [
    ./modules
    ./identities/gamzat.nix
    # dev-vm already imports desktop-apps.nix (apps: bitwarden, wezterm, …)
    ./profiles/dev-vm.nix
  ];

  home.username = "gamzat";
  home.homeDirectory = "/home/gamzat";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Non-NixOS: expose the HM profile to the Hyprland session. Omarchy boots
  # Hyprland via uwsm/systemd, so environment.d is the reliable hook (plain
  # KEY=value, no variable expansion — full PATH spelled out).
  targets.genericLinux.enable = true;
  xdg.configFile."environment.d/10-nix-profile-path.conf".text = ''
    PATH=/home/gamzat/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin
    XDG_DATA_DIRS=/home/gamzat/.nix-profile/share:/usr/local/share:/usr/share
  '';

  myHome.pi.enable = true;

  home.packages = with pkgs; [
    claude-code
    opencode
    rebuild-script
  ];
}
