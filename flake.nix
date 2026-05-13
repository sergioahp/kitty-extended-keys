{
  description = "Composable kitty config modules and wrapper package";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    let
      kittyLib = import ./lib { lib = nixpkgs.lib; };
      kittyFlakeModule = import ./flake-module.nix { inherit kittyLib; };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [ kittyFlakeModule ];

      perSystem = { config, pkgs, ... }: {
        kittyExtendedKeys = {
          features.base.enable = true;
          features.extendedKeys.enable = true;
        };

        packages.default = config.kittyExtendedKeys.rendered.package;

        apps.default = {
          type = "app";
          program =
            "${config.kittyExtendedKeys.rendered.package}/bin/${config.kittyExtendedKeys.rendered.mainProgram}";
        };

        devShells.default = pkgs.mkShell {
          packages = [ config.kittyExtendedKeys.rendered.package ];
        };
      };

      flake = {
        lib = kittyLib;
        flakeModules.default = kittyFlakeModule;
      };
    };
}
