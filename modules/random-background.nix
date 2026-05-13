{ defaults, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.kittyExtendedKeys.features.randomBackground = {
    enable = mkEnableOption "a wrapper that chooses a random background color for each launch";

    colors = mkOption {
      type = types.listOf types.str;
      default = defaults.randomBackgrounds;
      description = "Candidate background colors passed through `kitty --override background=...`.";
    };
  };
}
