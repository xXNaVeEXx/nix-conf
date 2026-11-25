{
  description = "Akio's NixOS & macOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    dotfiles = {
      url = "github:xXNaVeEXx/dotfiles";
      flake = false;
    };

    mangowc = {
      url = "github:DreamMaoMao/mangowc";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pi = {
      # Pinned on tag v1.6.1 (deterministic; tags since the upstream fix
      # d71c66e "pack pi-schema for the install lock" build under nix).
      # v1.6.1 is the minimum for the glm-5.4 model catalog on pi.dev
      # (catalog minimumPiVersion 1.5.3, supportDeveloperRole compat).
      url = "github:earendil-works/pi/ef4a1cfcca62b77ad3558337ff3e1c7f6beeadfe";
      # NO nixpkgs follows: our pinned nixpkgs' import-npm-lock chokes on pi's
      # package-lock ("attribute 'integrity' missing"); pi ships its own tested lock.
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-darwin,
      home-manager,
      darwin,
      dotfiles,
      mangowc,
      quickshell,
      sops-nix,
      pi,
    }:
    let
      mkHomeLinux =
        system: module:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."${system}";
          extraSpecialArgs = { inherit dotfiles sops-nix pi; };
          modules = [
            module
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];
            }
            sops-nix.homeManagerModules.sops
          ];
        };

      # Aliased entries — the .nix module is shared by multiple host attribute names
      cachyHome = mkHomeLinux "x86_64-linux" ./home/gamzat-cachyos.nix;
      sharedHome = mkHomeLinux "x86_64-linux" ./home/gamzat-shared.nix;
    in
    {
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit dotfiles mangowc quickshell sops-nix pi; };
          modules = [
            ./hosts/nixos/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit dotfiles mangowc quickshell sops-nix pi; };
              home-manager.users.gamzat = import ./home/gamzat.nix;
              home-manager.users.root = import ./home/root.nix;
              home-manager.sharedModules = [ sops-nix.homeManagerModules.sops ];
            }
          ];
        };
      };

      darwinConfigurations = {
        macbookpro = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit dotfiles sops-nix pi; };
          modules = [
            ./hosts/macbookpro/configuration.nix
            sops-nix.darwinModules.sops

            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit dotfiles sops-nix pi; };
              home-manager.users.gamzat = import ./home/gamzat-darwin.nix;
              home-manager.sharedModules = [ sops-nix.homeManagerModules.sops ];
            }
          ];
        };
      };

      # Standalone Home Manager (non-NixOS Linux: CachyOS, dev VMs, etc.)
      homeConfigurations = {
        "gamzat@cachyos" = cachyHome;
        "gamzat@cachydeck" = cachyHome;
        "gamzat@shared" = sharedHome;
        "gamzat@gamzat-dev" = sharedHome;
        "maga@maga-dev" = mkHomeLinux "x86_64-linux" ./home/maga-dev.nix;
        "marv@marv-dev" = mkHomeLinux "x86_64-linux" ./home/marv-dev.nix;
        "gamzat@omarchy" = mkHomeLinux "aarch64-linux" ./home/gamzat-omarchy.nix;
      };
    };
}
