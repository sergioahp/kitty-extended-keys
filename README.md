# kitty-extended-keys

Composable kitty configuration for Nix.

This repo now exposes:

- a `flake-parts` module for building a wrapped kitty package from merged options
- a small pure library for reusing the default attrsets and rendering them into kitty config text

It does not ship one package per feature. The intended model is:

- independent feature modules contribute defaults
- consumers override or extend through normal Nix module merging
- one final package and one final config are rendered from the merged schema

## What The Flake Exports

- `flakeModules.default`
  Imports the kitty module tree into your own `flake-parts` config.
- `lib.defaults`
  Importable attrsets and helper functions for the built-in keymaps, colors, and related defaults.
- `lib.render`
  Pure functions for turning attrsets into kitty `map`, `mouse_map`, `action_alias`, and setting lines.
- `lib.evalKittyExtendedKeys`
  Evaluates the module set directly with extra modules.
- `lib.mkKittyConfig`
  Returns the computed `kittyExtendedKeys.rendered` attrset.
- `lib.mkKittyConfigText`
  Returns only the final config text.
- `lib.mkKittyPackage`
  Returns only the wrapped package.

The default flake package enables:

- `kittyExtendedKeys.features.base.enable = true`
- `kittyExtendedKeys.features.extendedKeys.enable = true`

## Option Model

Feature modules write into these shared option sets:

- `kittyExtendedKeys.settings`
- `kittyExtendedKeys.actionAliases`
- `kittyExtendedKeys.keymaps`
- `kittyExtendedKeys.mouseMappings`
- `kittyExtendedKeys.extraLines`
- `kittyExtendedKeys.extraConfig`

Rendered outputs are available at:

- `kittyExtendedKeys.rendered.mainProgram`
- `kittyExtendedKeys.rendered.settingLines`
- `kittyExtendedKeys.rendered.actionAliasLines`
- `kittyExtendedKeys.rendered.keymapLines`
- `kittyExtendedKeys.rendered.mouseMappingLines`
- `kittyExtendedKeys.rendered.configText`
- `kittyExtendedKeys.rendered.configFile`
- `kittyExtendedKeys.rendered.package`

Core wrapper inputs are:

- `kittyExtendedKeys.package`
- `kittyExtendedKeys.mainProgram`
- `kittyExtendedKeys.wrapper.extraFlags`

## Features

- `kittyExtendedKeys.features.base`
  Base settings and colors.
- `kittyExtendedKeys.features.extendedKeys`
  The special ctrl and ctrl+shift escape sequences, exposed as an attrset before rendering.
- `kittyExtendedKeys.features.scrollback`
  `kitty-scrollback.nvim` integration, including descriptions moved onto option paths instead of inline comments.
- `kittyExtendedKeys.features.hyprvoice`
  Scrollback-aware hyprvoice launch chord. Consumers can provide either a package or a raw program path.
- `kittyExtendedKeys.features.randomBackground`
  Runtime wrapper that injects a random background color with `--override`.

## Using The Flake Module

```nix
{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs";
    kitty-extended-keys.url = "github:your-user/kitty-extended-keys";
  };

  outputs = inputs@{ flake-parts, kitty-extended-keys, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [ kitty-extended-keys.flakeModules.default ];

      perSystem = { config, pkgs, ... }: {
        kittyExtendedKeys = {
          package = pkgs.kitty;

          features.base.enable = true;
          features.extendedKeys.enable = true;
          features.scrollback.enable = true;
          features.hyprvoice.enable = true;
          features.hyprvoice.package =
            inputs.hyprvoice.packages.${pkgs.system}.default;

          settings.background_opacity = 0.9;

          keymaps."ctrl+shift+y" =
            "send_text application \\x1b[89;5u";

          extraConfig = ''
            shell_integration enabled
          '';
        };

        packages.default = config.kittyExtendedKeys.rendered.package;
      };
    };
}
```

Useful values after evaluation:

- `config.kittyExtendedKeys.rendered.package`
- `config.kittyExtendedKeys.rendered.configText`
- `config.kittyExtendedKeys.rendered.configFile`

## Hyprvoice Source Selection

The hyprvoice feature does not add a flake input in this repo.

That choice belongs in consumer config, under:

- `kittyExtendedKeys.features.hyprvoice.package`
- `kittyExtendedKeys.features.hyprvoice.packageMainProgram`
- `kittyExtendedKeys.features.hyprvoice.program`
- `kittyExtendedKeys.features.hyprvoice.args`
- `kittyExtendedKeys.features.hyprvoice.stdinSource`
- `kittyExtendedKeys.features.hyprvoice.launchType`
- `kittyExtendedKeys.features.hyprvoice.map.action`

Why this is the right place:

- consumers who do not enable the feature do not need to care where `hyprvoice` comes from
- this flake stays decoupled from one specific source or forge
- consumers can pick a flake input, a tarball fetch, a GitLab fetcher, an overlay, or just rely on PATH

Flake input example, matching the Home Manager setup:

```nix
kittyExtendedKeys.features.hyprvoice = {
  enable = true;
  package = inputs.hyprvoice.packages.${pkgs.system}.default;
};
```

Non-flake package example:

```nix
let
  hyprvoicePkg = pkgs.callPackage
    ({ buildGoModule, fetchFromGitLab, ... }:
      buildGoModule {
        pname = "hyprvoice";
        version = "unstable";
        src = fetchFromGitLab {
          owner = "sergioahp";
          repo = "hyprvoice";
          rev = "feature/context-transcription";
          hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };
        vendorHash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
      })
    { };
in
{
  kittyExtendedKeys.features.hyprvoice = {
    enable = true;
    package = hyprvoicePkg;
  };
}
```

PATH-based example:

```nix
kittyExtendedKeys.features.hyprvoice = {
  enable = true;
  program = "hyprvoice";
};
```

## Using The Pure Library

If you only want the attrsets and render helpers, you can skip the module layer.

```nix
let
  flake = builtins.getFlake "github:your-user/kitty-extended-keys";
  bindings =
    flake.lib.defaults.specialKeys
    // {
      "ctrl+shift+y" = "\\x1b[89;5u";
    };
  keymaps = flake.lib.render.mkSendTextMappings bindings;
  configText = flake.lib.render.renderConfigText {
    keymaps = keymaps;
  };
in
configText
```

That surface is meant for:

- merging built-in bindings with your own attrsets
- inspecting or filtering the defaults before rendering
- reusing the renderer in places that are not package-oriented

## Evaluating The Module Set Without flake-parts

The library also exposes a direct evaluator:

```nix
let
  flake = builtins.getFlake "github:your-user/kitty-extended-keys";
  pkgs = (builtins.getFlake "github:NixOS/nixpkgs").legacyPackages.x86_64-linux;
  rendered = flake.lib.mkKittyConfig {
    inherit pkgs;
    modules = [
      {
        kittyExtendedKeys.features.base.enable = true;
        kittyExtendedKeys.features.extendedKeys.enable = true;
        kittyExtendedKeys.features.randomBackground.enable = true;
      }
    ];
  };
in
rendered.package
```

## Defaults You Can Reuse

Available under `lib.defaults`:

- `specialKeys`
- `baseSettings`
- `baseColors`
- `scrollbackKeymaps`
- `scrollbackMouseMappings`
- `hyprvoiceKeymaps`
- `randomBackgrounds`

The function-valued defaults return plain data and do not mutate any module outputs on their own.

## Development

Build the default package:

```sh
nix build .#default
```

Inspect the exported defaults:

```sh
nix eval .#lib.defaults.specialKeys --json
```

Render the built-in special keys as kitty `map` lines:

```sh
nix eval --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
in
  flake.lib.render.renderKeymaps
    (flake.lib.render.mkSendTextMappings flake.lib.defaults.specialKeys)
' --json
```
