{ config, lib, pkgs, render, ... }:
let
  inherit (lib) mkOption types;

  kittyScalarType = types.oneOf [
    types.bool
    types.float
    types.int
    types.path
    types.str
  ];

  cfg = config.kittyExtendedKeys;
  mainProgram =
    if cfg.mainProgram != null then
      cfg.mainProgram
    else
      cfg.package.meta.mainProgram or cfg.package.pname or cfg.package.name or "kitty";

  keymapLines = render.renderKeymaps cfg.keymaps;
  mouseMappingLines = render.renderMouseMappings cfg.mouseMappings;
  settingLines = render.renderSettings cfg.settings;
  actionAliasLines = render.renderActionAliases cfg.actionAliases;

  configText = render.renderConfigText {
    inherit (cfg)
      actionAliases
      extraConfig
      extraLines
      keymaps
      mouseMappings
      settings
      ;
  };

  configFile = pkgs.writeText "kitty.conf" configText;

  wrapArgs =
    builtins.map
      lib.escapeShellArg
      (lib.concatMap (flag: [ "--add-flags" flag ]) ([ "--config ${configFile}" ] ++ cfg.wrapper.extraFlags));

  basePackage = pkgs.symlinkJoin {
    inherit (cfg.package) name;
    meta = cfg.package.meta or { };
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/${mainProgram}" ${lib.concatStringsSep " " wrapArgs}
    '';
  };

  randomBackgroundWrapper =
    if cfg.features.randomBackground.colors == [ ] then
      throw "kittyExtendedKeys.features.randomBackground.colors must not be empty when enabled."
    else
    pkgs.writeShellScript "kitty-random-background" ''
      colors=(
      ${lib.concatMapStringsSep "\n" (color: "  ${lib.escapeShellArg color}") cfg.features.randomBackground.colors}
      )
      idx=$((RANDOM % ''${#colors[@]}))
      exec ${basePackage}/bin/${mainProgram} --override "background=''${colors[$idx]}" "$@"
    '';

  wrappedPackage =
    if cfg.features.randomBackground.enable then
      pkgs.symlinkJoin {
        inherit (basePackage) name;
        meta = basePackage.meta or { };
        paths = [ basePackage ];
        postBuild = ''
          ln -sf ${randomBackgroundWrapper} "$out/bin/${mainProgram}"
        '';
      }
    else
      basePackage;
in
{
  options.kittyExtendedKeys = {
    package = mkOption {
      type = types.package;
      default = pkgs.kitty;
      description = "Base kitty package to wrap with the generated configuration.";
    };

    mainProgram = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Program name inside `package` to wrap. Defaults to `meta.mainProgram` or `pname`.";
    };

    settings = mkOption {
      type = types.attrsOf kittyScalarType;
      default = { };
      description = "Merged kitty settings rendered as `name value` lines.";
    };

    actionAliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Merged kitty action aliases rendered as `action_alias name action` lines.";
    };

    keymaps = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Merged keyboard mappings rendered as `map key action` lines.";
    };

    mouseMappings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Merged mouse mappings rendered as `mouse_map key action` lines.";
    };

    extraLines = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Raw kitty config lines appended after the rendered sections.";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra literal kitty config appended after the rendered sections.";
    };

    wrapper.extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional `wrapProgram --add-flags` entries for the wrapped kitty binary.";
    };

    rendered.mainProgram = mkOption {
      type = types.str;
      readOnly = true;
      description = "Resolved wrapped program name.";
    };

    rendered.settingLines = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = "Rendered `setting value` lines.";
    };

    rendered.actionAliasLines = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = "Rendered `action_alias` lines.";
    };

    rendered.keymapLines = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = "Rendered `map` lines.";
    };

    rendered.mouseMappingLines = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = "Rendered `mouse_map` lines.";
    };

    rendered.configText = mkOption {
      type = types.lines;
      readOnly = true;
      description = "The final kitty configuration text assembled from the merged schema.";
    };

    rendered.configFile = mkOption {
      type = types.package;
      readOnly = true;
      description = "A store path containing the final kitty configuration text.";
    };

    rendered.package = mkOption {
      type = types.package;
      readOnly = true;
      description = "The wrapped kitty package built from the merged schema.";
    };
  };

  config = {
    kittyExtendedKeys.rendered = {
      inherit
        actionAliasLines
        configFile
        configText
        keymapLines
        mainProgram
        mouseMappingLines
        settingLines
        ;
      package = wrappedPackage;
    };
  };
}
