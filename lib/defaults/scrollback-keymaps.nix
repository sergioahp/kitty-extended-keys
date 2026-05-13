{ aliasName ? "kitty_scrollback_nvim" }:
{
  "kitty_mod+h" = aliasName;
  "kitty_mod+g" = "${aliasName} --config ksb_builtin_last_cmd_output";
}
