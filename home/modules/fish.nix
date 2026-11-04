# Fish shell config from the dotfiles repo (fish/ subtree). The shell binary
# itself comes from the distro (Omarchy ships fish as default shell), so this
# is a pure dotfiles deployment — no package attached.
{ lib, dotfiles, ... }:

{
  # Deploy unconditionally when enabled: config is distro-agnostic, the
  # WSL/macOS/PATH guards in config.fish no-op on machines where the paths
  # don't exist.
  home.file.".config/fish" = {
    source = "${dotfiles}/fish";
    recursive = true;
  };
}
