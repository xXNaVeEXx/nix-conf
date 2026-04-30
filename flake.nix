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
    }:
    let
      mkHomeLinux =
        module:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit dotfiles sops-nix; };
          modules = [
            module
            { nixpkgs.config.allowUnfree = true; }
            sops-nix.homeManagerModules.sops
          ];
        };

      # Aliased entries — the .nix module is shared by multiple host attribute names
      cachyHome = mkHomeLinux ./home/gamzat-cachyos.nix;
      sharedHome = mkHomeLinux ./home/gamzat-shared.nix;
    in
    {
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit dotfiles mangowc quickshell sops-nix; };
          modules = [
            ./hosts/nixos/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit dotfiles mangowc quickshell sops-nix; };
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
          specialArgs = { inherit dotfiles sops-nix; };
          modules = [
            ./hosts/macbookpro/configuration.nix
            sops-nix.darwinModules.sops

            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit dotfiles sops-nix; };
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
        "maga@maga-dev" = mkHomeLinux ./home/maga-dev.nix;
        "marv@marv-dev" = mkHomeLinux ./home/marv-dev.nix;
      };

      packages.x86_64-linux.dioxus-shell =
        nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/dioxus-shell { };
    };
}
