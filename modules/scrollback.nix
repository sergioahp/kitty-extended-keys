{ config, defaults, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption mkDefault types;
  cfg = config.kittyExtendedKeys.features.scrollback;
  keymaps = defaults.scrollbackKeymaps { aliasName = cfg.actionAlias.name; };
  mouseMappings = defaults.scrollbackMouseMappings { aliasName = cfg.actionAlias.name; };
in
{
  options.kittyExtendedKeys.features.scrollback = {
    enable = mkEnableOption "kitty-scrollback integration";

    allowRemoteControl = mkOption {
      type = types.str;
      default = "socket-only";
      description = "Value for kitty's `allow_remote_control` setting.";
    };

    listenOn = mkOption {
      type = types.str;
      default = "unix:/tmp/kitty";
      description = "Socket path used by kitty for remote control.";
    };

    actionAlias.name = mkOption {
      type = types.str;
      default = "kitty_scrollback_nvim";
      description = "Alias used by the scrollback keymaps.";
    };

    actionAlias.command = mkOption {
      type = types.str;
      default =
        "kitten /home/admin/.local/share/nvim/lazy/kitty-scrollback.nvim/python/kitty_scrollback_nvim.py";
      description = "Command used to open kitty scrollback in Neovim.";
    };

    browseBuffer.key = mkOption {
      type = types.str;
      default = "kitty_mod+h";
      description = "Browse the scrollback buffer in Neovim.";
    };

    lastCommandOutput.key = mkOption {
      type = types.str;
      default = "kitty_mod+g";
      description = "Browse the output of the last shell command in Neovim.";
    };

    clickedCommandOutput.trigger = mkOption {
      type = types.str;
      default = "ctrl+shift+right press ungrabbed";
      description = "Show clicked command output in Neovim.";
    };
  };

  config = mkIf cfg.enable {
    kittyExtendedKeys.settings = {
      allow_remote_control = mkDefault cfg.allowRemoteControl;
      listen_on = mkDefault cfg.listenOn;
    };

    kittyExtendedKeys.actionAliases = mkDefault {
      "${cfg.actionAlias.name}" = cfg.actionAlias.command;
    };

    kittyExtendedKeys.keymaps = mkDefault (
      {
        "${cfg.browseBuffer.key}" = keymaps."kitty_mod+h";
        "${cfg.lastCommandOutput.key}" = keymaps."kitty_mod+g";
      }
    );

    kittyExtendedKeys.mouseMappings = mkDefault (
      {
        "${cfg.clickedCommandOutput.trigger}" = mouseMappings."ctrl+shift+right press ungrabbed";
      }
    );
  };
}
