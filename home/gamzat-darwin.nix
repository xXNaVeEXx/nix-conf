{ pkgs, ... }:

{
  imports = [
    ./modules
    ./identities/gamzat.nix
    ./profiles/from-os-config.nix
  ];

  home.stateVersion = "25.11";
  home.username = "gamzat";
  home.homeDirectory = "/Users/gamzat";

  myHome = {
    kube.enable = true;
    dev.enable = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs; [
    go
    kubectl

    # AI tooling
    claude-code
    gemini-cli
    opencode

    # Languages beyond the dev base
    bun
    python3
    typescript
  ];
}
