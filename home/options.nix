{ lib, ... }:

{
  options.myHome = {
    identity = {
      name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Full name for git commits. null disables the git module.";
      };
      email = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Email for git commits. null disables the git module.";
      };
      sshKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "~/.ssh/id_ed25519";
        description = "Path to SSH private key for github.com. null disables the ssh module.";
      };
    };

    sops = {
      enable = lib.mkEnableOption "sops-nix integration with secrets/secrets.yaml";
      ageKeyFile = lib.mkOption {
        type = lib.types.str;
        example = "/home/user/.config/sops/age/key.txt";
        description = "Absolute path to the age key used to decrypt secrets.";
      };
    };

    dev.enable = lib.mkEnableOption "developer toolchain (compilers + LSP servers)";

    apps = {
      bitwarden = lib.mkEnableOption "Bitwarden desktop + CLI";
      wezterm = lib.mkEnableOption "WezTerm terminal emulator + dotfiles";
      moonlight = lib.mkEnableOption "Moonlight game streaming client";
      clipboard = lib.mkEnableOption "Clipboard manager (CopyQ on Linux, Maccy on macOS)";
    };

    kube.enable = lib.mkEnableOption "~/.config/.kube symlink from dotfiles";
  };
}
