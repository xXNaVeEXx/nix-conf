{ pkgs }:

pkgs.writeScriptBin "rebuild" ''
  #!/usr/bin/env bash

  # Find nix-config directory
  if [ -d "$HOME/projects/nix-conf" ]; then
    CONFIG_DIR="$HOME/projects/nix-conf"
  elif [ -d "$HOME/nix-config" ]; then
    CONFIG_DIR="$HOME/nix-config"
  elif [ -d /etc/nixos ]; then
    CONFIG_DIR="/etc/nixos"
  else
    echo "Error: Could not find nix-config directory"
    exit 1
  fi

  cd "$CONFIG_DIR"
  exec ${pkgs.bash}/bin/bash "$CONFIG_DIR/rebuild.sh" "$@"
''
