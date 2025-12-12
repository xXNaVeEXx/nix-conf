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
    }:
    {
      # NixOS Configuration
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit dotfiles mangowc quickshell; };
          modules = [
            ./hosts/nixos/configuration.nix

            { nixpkgs.config.allowUnfree = true; }

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit dotfiles mangowc quickshell; };
              home-manager.users.gamzat = import ./home/gamzat.nix;
              home-manager.users.root = import ./home/root.nix;
            }
          ];
        };
      };

      # macOS Configuration
      darwinConfigurations = {
        macbook = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit dotfiles; };
          modules = [
            ./hosts/macbook/configuration.nix

            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit dotfiles; };
              home-manager.users.gamzat = import ./home/gamzat-darwin.nix;
            }
          ];
        };
      };

      # Standalone Home Manager Configuration (for CachyOS and other non-NixOS systems)
      homeConfigurations = {
        "gamzat@cachyos" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit dotfiles; };
          modules = [
            ./home/gamzat-cachyos.nix
            { nixpkgs.config.allowUnfree = true; }
          ];
        };

        # Shared configuration for gamzat-dev and other systems
        "gamzat@shared" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit dotfiles; };
          modules = [
            ./home/gamzat-shared.nix
            { nixpkgs.config.allowUnfree = true; }
          ];
        };

        # Configuration for gamzat-dev hostname
        "gamzat@gamzat-dev" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit dotfiles; };
          modules = [
            ./home/gamzat-shared.nix
            { nixpkgs.config.allowUnfree = true; }
          ];
        };
      };
    };
}
