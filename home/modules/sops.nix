{ config, lib, pkgs, ... }:

let
  cfg = config.myHome.sops;
in

{
  config = lib.mkIf cfg.enable {
    sops = {
      age.keyFile = cfg.ageKeyFile;
      defaultSopsFile = ../../secrets/secrets.yaml;
    };

    home.packages = with pkgs; [ sops age ];

    home.file.".config/sops/.sops.yaml".text = ''
      keys:
        - &admin_key age14pdqf7sl4sltz442mvfyafchvxn5wvv988gv6enhhrmyx3ch5qfs5y6atl

      creation_rules:
        # Kubernetes configs
        - path_regex: \.kube/.*
          age: *admin_key

        # All other files
        - path_regex: .*
          age: *admin_key
    '';
  };
}
