{
  description = "Native NixOS package for Nexus Mods Vortex";

  nixConfig = {
    extra-substituters = [ "https://vortex-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "vortex-nix.cachix.org-1:7+ZVU0umNp8sz1JqZV/bRcbVgemNuNtzN5KiJxihFRY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    vortex-src = {
      url = "github:Nexus-Mods/Vortex/v2.3.0";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, vortex-src, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      vortex = pkgs.callPackage ./package.nix { src = vortex-src; };
    in
    {
      packages.${system} = {
        default = vortex;
        inherit vortex;
      };

      apps.${system}.default = {
        type = "app";
        program = "${vortex}/bin/vortex";
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
