{ lib }:
let
  render = import ./render.nix { inherit lib; };
  defaults = {
    baseColors = import ./defaults/base-colors.nix;
    baseSettings = import ./defaults/base-settings.nix;
    hyprvoiceKeymaps = import ./defaults/hyprvoice-keymaps.nix;
    randomBackgrounds = import ./defaults/random-backgrounds.nix;
    scrollbackKeymaps = import ./defaults/scrollback-keymaps.nix;
    scrollbackMouseMappings = import ./defaults/scrollback-mouse-mappings.nix;
    specialKeys = import ./defaults/special-keys.nix;
  };
  moduleImports = [
    ../modules/core.nix
    ../modules/base.nix
    ../modules/extended-keys.nix
    ../modules/scrollback.nix
    ../modules/hyprvoice.nix
    ../modules/random-background.nix
  ];
in
rec {
  inherit defaults moduleImports render;

  evalKittyExtendedKeys = {
    pkgs,
    modules ? [ ],
    specialArgs ? { },
  }:
    lib.evalModules {
      specialArgs =
        {
          inherit defaults pkgs render;
        }
        // specialArgs;
      modules = moduleImports ++ modules;
    };

  mkKittyConfig = args:
    (evalKittyExtendedKeys args).config.kittyExtendedKeys.rendered;

  mkKittyConfigText = args:
    (mkKittyConfig args).configText;

  mkKittyPackage = args:
    (mkKittyConfig args).package;
}
