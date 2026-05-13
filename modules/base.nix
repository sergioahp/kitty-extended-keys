{ defaults, lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption mkDefault types;
  kittyScalarType = types.oneOf [
    types.bool
    types.float
    types.int
    types.path
    types.str
  ];
  cfg = config.kittyExtendedKeys.features.base;
in
{
  options.kittyExtendedKeys.features.base = {
    enable = mkEnableOption "base kitty settings and colors";

    settings = mkOption {
      type = types.attrsOf kittyScalarType;
      default = defaults.baseSettings;
      description = "Base kitty settings merged into `kittyExtendedKeys.settings`.";
    };

    colors = mkOption {
      type = types.attrsOf types.str;
      default = defaults.baseColors;
      description = "The color subset of the base settings, exposed separately for easy inspection and extension.";
    };
  };

  config = mkIf cfg.enable {
    kittyExtendedKeys.settings =
      mkDefault
        (cfg.settings // cfg.colors);
  };
}
