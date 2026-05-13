{ config, defaults, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption mkDefault types;
  cfg = config.kittyExtendedKeys.features.hyprvoice;
  resolvedProgram =
    if cfg.package != null then
      "${cfg.package}/bin/${
        if cfg.packageMainProgram != null then
          cfg.packageMainProgram
        else
          cfg.package.meta.mainProgram or cfg.package.pname or cfg.package.name or "hyprvoice"
      }"
    else
      cfg.program;
  command =
    "launch --stdin-source=${cfg.stdinSource} --type=${cfg.launchType} "
    + lib.escapeShellArgs ([ resolvedProgram ] ++ cfg.args);
  action =
    if cfg.map.action != null then
      cfg.map.action
    else
      command;
  keymaps = defaults.hyprvoiceKeymaps { command = action; };
in
{
  options.kittyExtendedKeys.features.hyprvoice = {
    enable = mkEnableOption "hyprvoice recording with terminal scrollback context";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Optional package used to resolve the hyprvoice executable path.
        This keeps source selection in consumer code, so consumers can use
        flake inputs, `fetchTarball`, GitLab fetchers, overlays, or plain PATH lookup.
      '';
    };

    packageMainProgram = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Binary name inside `package`. Defaults to `meta.mainProgram`, then `pname`,
        then `name`, and finally `hyprvoice`.
      '';
    };

    program = mkOption {
      type = types.str;
      default = "hyprvoice";
      description = ''
        Program path or name to use when `package` is null.
        This lets consumers rely on PATH or provide an explicit executable path.
      '';
    };

    args = mkOption {
      type = types.listOf types.str;
      default = [ "toggle" ];
      description = "Arguments passed to the hyprvoice executable.";
    };

    stdinSource = mkOption {
      type = types.str;
      default = "@screen_scrollback";
      description = "Value passed to `launch --stdin-source=...`.";
    };

    launchType = mkOption {
      type = types.str;
      default = "background";
      description = "Value passed to `launch --type=...`.";
    };

    map.key = mkOption {
      type = types.str;
      default = "ctrl+period>ctrl+period";
      description = "Start recording with terminal scrollback as transcription context.";
    };

    map.action = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Optional full kitty action override.
        When null, the action is derived from `package` or `program`,
        together with `args`, `stdinSource`, and `launchType`.
      '';
    };
  };

  config = mkIf cfg.enable {
    kittyExtendedKeys.keymaps = mkDefault (
      {
        "${cfg.map.key}" = keymaps."ctrl+period>ctrl+period";
      }
    );
  };
}
