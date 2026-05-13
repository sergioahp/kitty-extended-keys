{ aliasName ? "kitty_scrollback_nvim" }:
{
  "ctrl+shift+right press ungrabbed" =
    "combine : mouse_select_command_output : ${aliasName} --config ksb_builtin_last_visited_cmd_output";
}
