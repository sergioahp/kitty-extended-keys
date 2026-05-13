{ config, defaults, lib, render, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption mkDefault types;
  cfg = config.kittyExtendedKeys.features.extendedKeys;
in
{
  options.kittyExtendedKeys.features.extendedKeys = {
    enable = mkEnableOption "extended ctrl and ctrl+shift kitty key chords";

    bindings = mkOption {
      type = types.attrsOf types.str;
      default = defaults.specialKeys;
      description = ''
        Escape sequences keyed by kitty shortcuts. They are transformed into
        `send_text application` mappings and merged into `kittyExtendedKeys.keymaps`.
      '';
    };
  };

  config = mkIf cfg.enable {
    kittyExtendedKeys.keymaps = mkDefault (render.mkSendTextMappings cfg.bindings);
  };
}
