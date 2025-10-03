{
  description = "Kitty extended keys as a pkg + devShell (no Home Manager needed)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs }:
  let
    mkFor = system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        # --- Extended key bindings (matches your system kitty config) ---
        bindings = {
          # Control + letters
          "ctrl+h"        = "\\x1b[104;5u";
          "ctrl+i"        = "\\x1b[105;5u";
          "ctrl+j"        = "\\x1b[106;5u";
          "ctrl+m"        = "\\x1b[109;5u";

          # Control+Shift + letters (note: some commented out in your config)
          "ctrl+shift+a"  = "\\x1b[65;5u";
          # "ctrl+shift+b" = "\\x1b[66;5u";  # commented in your config
          # "ctrl+shift+c" = "\\x1b[67;5u";  # commented in your config
          "ctrl+shift+d"  = "\\x1b[68;5u";
          "ctrl+shift+e"  = "\\x1b[69;5u";
          # "ctrl+shift+f" = "\\x1b[70;5u";  # commented in your config
          "ctrl+shift+g"  = "\\x1b[71;5u";
          "ctrl+shift+h"  = "\\x1b[72;5u";
          "ctrl+shift+i"  = "\\x1b[73;5u";
          "ctrl+shift+j"  = "\\x1b[74;5u";
          "ctrl+shift+k"  = "\\x1b[75;5u";
          "ctrl+shift+l"  = "\\x1b[76;5u";
          "ctrl+shift+m"  = "\\x1b[77;5u";
          "ctrl+shift+n"  = "\\x1b[78;5u";
          "ctrl+shift+o"  = "\\x1b[79;5u";
          "ctrl+shift+p"  = "\\x1b[80;5u";
          "ctrl+shift+q"  = "\\x1b[81;5u";
          "ctrl+shift+r"  = "\\x1b[82;5u";
          "ctrl+shift+s"  = "\\x1b[83;5u";
          "ctrl+shift+t"  = "\\x1b[84;5u";
          "ctrl+shift+u"  = "\\x1b[85;5u";
          # "ctrl+shift+v" = "\\x1b[86;5u";  # commented in your config
          "ctrl+shift+w"  = "\\x1b[87;5u";
          "ctrl+shift+x"  = "\\x1b[88;5u";
          "ctrl+shift+y"  = "\\x1b[89;5u";
          "ctrl+shift+z"  = "\\x1b[90;5u";

          # Control + digits (ctrl+0 commented in your config)
          "ctrl+1"        = "\\x1b[49;5u";
          "ctrl+2"        = "\\x1b[50;5u";
          "ctrl+3"        = "\\x1b[51;5u";
          "ctrl+4"        = "\\x1b[52;5u";
          "ctrl+5"        = "\\x1b[53;5u";
          "ctrl+6"        = "\\x1b[54;5u";
          "ctrl+7"        = "\\x1b[55;5u";
          "ctrl+8"        = "\\x1b[56;5u";
          "ctrl+9"        = "\\x1b[57;5u";

          # Control+Shift + digits
          "ctrl+shift+0"  = "\\x1b[48;6u";
          "ctrl+shift+1"  = "\\x1b[49;6u";
          "ctrl+shift+2"  = "\\x1b[50;6u";
          "ctrl+shift+3"  = "\\x1b[51;6u";
          "ctrl+shift+4"  = "\\x1b[52;6u";
          "ctrl+shift+5"  = "\\x1b[53;6u";
          "ctrl+shift+6"  = "\\x1b[54;6u";
          "ctrl+shift+7"  = "\\x1b[55;6u";
          "ctrl+shift+8"  = "\\x1b[56;6u";
          "ctrl+shift+9"  = "\\x1b[57;6u";
        };

        mkLine = k: v: "map ${k} send_text application ${v}";
        cfgText = lib.concatStringsSep "\n" (lib.mapAttrsToList mkLine bindings) + "\n";

        extended-keys-conf = pkgs.writeTextFile {
          name = "kitty-extended-keys.conf";
          text = cfgText;
        };

        # Kitty clipboard handler script for Claude Code integration (Lua version)
        kitty-clipboard-handler = pkgs.writeTextFile {
          name = "kitty-clipboard-handler.lua";
          executable = true;
          text = /*lua*/''
            #!${pkgs.lua}/bin/lua

            -- Simplified Wayland-only clipboard handler for kitty
            -- Handles both images (save to temp file) and text (kitty paste)

            local os = require("os")
            local io = require("io")

            -- Debug function
            local function debug(msg)
              io.stderr:write("[DEBUG] " .. msg .. "\n")
            end

            -- Check if we have required environment
            if not os.getenv("WAYLAND_DISPLAY") then
              io.stderr:write("kitty-clipboard: Wayland environment required\n")
              os.exit(1)
            end

            debug("KITTY_LISTEN_ON=" .. (os.getenv("KITTY_LISTEN_ON") or "unset"))
            debug("WAYLAND_DISPLAY=" .. (os.getenv("WAYLAND_DISPLAY") or "unset"))

            -- Get clipboard types
            local function get_clipboard_types()
              local handle = io.popen("${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null")
              if not handle then return "" end
              local result = handle:read("*a") or ""
              handle:close()
              return result
            end

            -- Save image from clipboard to temp file
            local function save_image(mime_type)
              local tmpdir = os.getenv("TMPDIR") or "/tmp"
              local timestamp = os.time()
              local pid = os.getenv("$") or "0"
              local filename = string.format("%s/kitty-clipboard-%s-%s.png", tmpdir, timestamp, pid)
              
              local cmd = string.format("${pkgs.wl-clipboard}/bin/wl-paste --type '%s' > '%s'", mime_type, filename)
              local success = os.execute(cmd) == 0
              
              if success then
                return filename
              else
                return nil
              end
            end

            -- Send text to kitty
            local function send_to_kitty(text)
              local listen_on = os.getenv("KITTY_LISTEN_ON")
              
              local cmd
              if listen_on then
                cmd = string.format("${pkgs.kitty}/bin/kitty @ --to '%s' send-text --stdin", listen_on)
              else
                cmd = "${pkgs.kitty}/bin/kitty @ send-text --stdin"
              end
              
              debug("send_to_kitty command: " .. cmd)
              debug("text to send: " .. text)
              
              local handle = io.popen(cmd, "w")
              if not handle then 
                debug("failed to open pipe")
                return false 
              end
              
              handle:write(text)
              local ok, exit_type, exit_code = handle:close()
              
              debug(string.format("close result: ok=%s, type=%s, code=%s", 
                tostring(ok), tostring(exit_type), tostring(exit_code)))
              
              return ok and (exit_type == "exit" and exit_code == 0)
            end

            -- Paste from clipboard using kitty
            local function paste_text()
              local listen_on = os.getenv("KITTY_LISTEN_ON")
              local cmd
              
              if listen_on then
                cmd = string.format("${pkgs.kitty}/bin/kitty @ --to '%s' action paste_from_clipboard", listen_on)
              else
                cmd = "${pkgs.kitty}/bin/kitty @ action paste_from_clipboard"
              end
              
              debug("paste_text command: " .. cmd)
              local result = os.execute(cmd)
              debug("paste_text result: " .. tostring(result))
              
              return result == true
            end

            -- Shell quote a string
            local function shell_quote(str)
              return "'" .. str:gsub("'", "'\"'\"'") .. "'"
            end

            -- Main logic
            local types = get_clipboard_types()
            debug("clipboard types: " .. types)

            if types:match("image/") then
              -- Handle image
              debug("detected image in clipboard")
              local mime_type = types:match("image/png") or types:match("image/[^%s]*")
              if mime_type then
                debug("using mime type: " .. mime_type)
                local filename = save_image(mime_type)
                if filename then
                  local quoted = shell_quote(filename)
                  debug("sending quoted filename: " .. quoted)
                  if not send_to_kitty(quoted) then
                    io.stderr:write("kitty-clipboard: failed to send image path to kitty\n")
                    os.exit(1)
                  end
                  debug("image path sent successfully")
                else
                  io.stderr:write("kitty-clipboard: failed to save image\n")
                  os.exit(1)
                end
              end
            else
              -- Handle text
              debug("no image detected, handling as text")
              if not paste_text() then
                io.stderr:write("kitty-clipboard: failed to paste text\n")
                os.exit(1)
              end
              debug("text paste completed successfully")
            end
          '';
        };

        # Base kitty configuration (without the keys and clip2path)
        base-kitty-conf = pkgs.writeTextFile {
          name = "kitty-base.conf";
          text = ''
            # Kitty Configuration
            # Generated from home-manager alacritty config

            font_size 12

            # Cursor
            cursor_blink_interval 0
            cursor_trail 1
            cursor_trail_decay 0.05 0.1

            # Window
            confirm_os_window_close 0

            # Transparency
            background_opacity 0.8

            # Color scheme (Tokyo Night)
            foreground #c0caf5
            background #282c3c

            # Normal colors
            color1  #f7768e
            color2  #9ece6a
            color3  #e0af68
            color4  #7aa2f7
            color5  #bb9af7
            color6  #7dcfff
            color7  #a9b1d6

            # Bright colors
            color9  #ff899d
            color10 #9fe044
            color11 #faba4a
            color12 #8db0ff
            color13 #c7a9ff
            color14 #a4daff
            color15 #c0caf5

            # Additional colors
            color16 #ff9e64
            color17 #db4b4b

            # kitty-scrollback
            allow_remote_control socket-only
            allow_remote_control yes

            listen_on unix:/tmp/kitty
            # kitty-scrollback.nvim Kitten alias
            action_alias kitty_scrollback_nvim kitten /home/admin/.local/share/nvim/lazy/kitty-scrollback.nvim/python/kitty_scrollback_nvim.py
            # Browse scrollback buffer in nvim
            map kitty_mod+h kitty_scrollback_nvim
            # Browse output of the last shell command in nvim
            map kitty_mod+g kitty_scrollback_nvim --config ksb_builtin_last_cmd_output
            # Show clicked command output in nvim
            mouse_map ctrl+shift+right press ungrabbed combine : mouse_select_command_output : kitty_scrollback_nvim --config ksb_builtin_last_visited_cmd_output
          '';
        };

        # Claude Code clipboard integration config
        claude-code-conf = pkgs.writeTextFile {
          name = "kitty-claude-code.conf";
          text = ''
            # claude code
            # Hybrid clipboard handler: images -> file paths, text -> kitty paste
            map ctrl+shift+v launch --type=background --allow-remote-control --keep-focus ${kitty-clipboard-handler}
          '';
        };

        # Create a kitty variant with extended keys built-in
          # kitty ignores system config if profided config arg
          # TODO: a postfixup wrapper for convenince (the user could pass
          # extra --config kwargs for using his config) (Not sure if we
          # want to do this, it's not too much effort to pass
          # ~/.config/kitty/kitty.conf
          # TODO: should kitty-extended reflect kitty version?
          kitty-extended = (pkgs.symlinkJoin {
            pname = "kitty-extended";
            version = "0.0.1";
            paths = [ pkgs.kitty ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/kitty \
                --add-flags "--config ${base-kitty-conf} --config ${claude-code-conf} --config ${extended-keys-conf}"
            '';
          });
      in
      {
        packages = {
          default = kitty-extended;
          extended-keys-conf = extended-keys-conf;
          base-kitty-conf = base-kitty-conf;
          claude-code-conf = claude-code-conf;
          kitty-clipboard-handler = kitty-clipboard-handler;
          kitty-extended = kitty-extended;
        };

        apps.default = {
          type = "app";
          program = "${kitty-extended}/bin/kitty";
        };

        devShells.default = pkgs.mkShell {
          packages = [ kitty-extended ];
        };
      };
  in
  {
    # Build for common systems; add others as needed
    packages.x86_64-linux = (mkFor "x86_64-linux").packages;
    packages.aarch64-linux = (mkFor "aarch64-linux").packages;
    devShells.x86_64-linux = (mkFor "x86_64-linux").devShells;
    devShells.aarch64-linux = (mkFor "aarch64-linux").devShells;
    apps.x86_64-linux = (mkFor "x86_64-linux").apps;
    apps.aarch64-linux = (mkFor "aarch64-linux").apps;
  };
}
