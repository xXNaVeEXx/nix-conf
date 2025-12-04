{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Oder für stable: "github:NixOS/nixpkgs/nixos-24.11"

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Deine Dotfiles als Input
    dotfiles = {
      url = "github:xXNaVeEXx/dotfiles";
      flake = false; # Kein Flake, nur Dateien
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      dotfiles,
    }:
    {
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit dotfiles; }; # An Home-Manager weitergeben
              home-manager.users.gamzat = import ./home/gamzat.nix;
              home-manager.users.root = import ./home/root.nix;
            }
          ];
        };
      };
    };
}
