{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.myHome.dev.enable {
    home.packages = with pkgs; [
      clang
      nodejs
      unzip
      rustup

      lua-language-server
      nil
      typescript-language-server
      clang-tools
      vscode-langservers-extracted
    ];
  };
}
