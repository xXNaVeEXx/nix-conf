{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.myHome.dev.enable {
    home.packages = with pkgs; [
      clang
      nodejs
      unzip
      cargo
      rustc

      lua-language-server
      nil
      typescript-language-server
      rust-analyzer
      clang-tools
      vscode-langservers-extracted
    ];
  };
}
