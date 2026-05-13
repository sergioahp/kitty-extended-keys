{ lib }:
let
  sortAttrNames = attrs:
    builtins.sort builtins.lessThan (builtins.attrNames attrs);

  renderAttrs = renderLine: attrs:
    builtins.map (name: renderLine name attrs.${name}) (sortAttrNames attrs);
in
rec {
  toKittyValue = value:
    if builtins.isBool value then
      lib.boolToString value
    else if builtins.isInt value || builtins.isFloat value || builtins.isString value then
      toString value
    else if builtins.isPath value then
      toString value
    else
      throw "Unsupported kitty config value type: ${builtins.typeOf value}";

  mkSendTextAction = text: "send_text application ${text}";

  mkSendTextMappings = bindings:
    lib.mapAttrs (_: text: mkSendTextAction text) bindings;

  renderSettings = settings:
    renderAttrs (name: value: "${name} ${toKittyValue value}") settings;

  renderActionAliases = aliases:
    renderAttrs (name: value: "action_alias ${name} ${value}") aliases;

  renderKeymaps = keymaps:
    renderAttrs (name: value: "map ${name} ${value}") keymaps;

  renderMouseMappings = mouseMappings:
    renderAttrs (name: value: "mouse_map ${name} ${value}") mouseMappings;

  renderConfigText = {
    settings ? { },
    actionAliases ? { },
    keymaps ? { },
    mouseMappings ? { },
    extraLines ? [ ],
    extraConfig ? "",
  }:
    let
      sections =
        [
          (renderSettings settings)
          (renderActionAliases actionAliases)
          (renderKeymaps keymaps)
          (renderMouseMappings mouseMappings)
          extraLines
        ]
        ++ lib.optional (extraConfig != "") [ extraConfig ];
      lines = lib.flatten (builtins.filter (section: section != [ ]) sections);
    in
    lib.concatStringsSep "\n" lines + "\n";
}
