{ config, lib, pkgs, dotfiles, ... }:

let
  cfg = config.myHome.apps;
  clipboardPkg = if pkgs.stdenv.isDarwin then pkgs.maccy else pkgs.copyq;
in

{
  home.packages =
    (lib.optionals cfg.bitwarden (with pkgs; [ bitwarden-desktop bitwarden-cli ]))
    ++ lib.optionals cfg.wezterm [ pkgs.wezterm ]
    ++ lib.optionals cfg.moonlight [ pkgs.moonlight-qt ]
    ++ lib.optionals cfg.clipboard [ clipboardPkg ];

  home.file.".config/wezterm" = lib.mkIf cfg.wezterm {
    source = "${dotfiles}/wezterm";
    recursive = true;
  };
}
