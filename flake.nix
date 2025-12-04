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
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-darwin,
      home-manager,
      darwin,
      dotfiles,
    }:
    {
      # NixOS Configuration
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit dotfiles; };
          modules = [
            ./hosts/nixos/configuration.nix

            { nixpkgs.config.allowUnfree = true; }

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit dotfiles; };
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
              home-manager.extraSpecialArgs = { inherit dotfiles; };
              home-manager.users.gamzat = import ./home/gamzat-darwin.nix;
            }
          ];
        };
      };
    };
}
