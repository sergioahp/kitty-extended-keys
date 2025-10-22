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

        # Kitty clipboard handler script for Claude Code integration
        kitty-clipboard-handler = pkgs.writeShellScript "kitty-clipboard-handler" ''
          #!/usr/bin/env bash
          # clip2path — robust Wayland/X11 clipboard → Kitty hybrid paste handler
          # - Text in clipboard ⇒ use kitty's paste-from-clipboard (with safety features)
          # - Image in clipboard ⇒ save to a unique temp file and paste its quoted path.
          #
          # Requirements: kitty, and either:
          #   - Wayland: wl-clipboard (wl-paste)
          #   - X11: xclip or xsel
          # Kitty mapping must use `--allow-remote-control` so KITTY_LISTEN_ON is set.
          #
          # Optional env:
          #   CLIP2PATH_TMPDIR   : directory for saved images (default: $TMPDIR or /tmp)
          #   CLIP2PATH_DEBUG=1  : emit debug info to stderr

          set -Eeuo pipefail
          IFS=$'\n\t'
          umask 077
          export LC_ALL=C

          # ----- utilities -------------------------------------------------------------

          debug() { [[ "''${CLIP2PATH_DEBUG:-0}" == "1" ]] && printf '[kitty-clipboard] %s\n' "$*" >&2 || true; }

          die() {
            printf 'kitty-clipboard: %s\n' "$*" >&2
            exit 1
          }

          have() { command -v "$1" >/dev/null 2>&1; }

          # Detect display server environment
          detect_display_server() {
            if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
              echo "wayland"
            elif [[ -n "''${DISPLAY:-}" ]]; then
              echo "x11"
            else
              echo "unknown"
            fi
          }

          # Choose preferred X11 clipboard tool (prefer xclip over xsel)
          choose_x11_tool() {
            if have xclip; then
              echo "xclip"
            elif have xsel; then
              echo "xsel"
            else
              echo "none"
            fi
          }

          # Use Kitty's per-launch control socket if available (set by --allow-remote-control).
          kitty_send_text() {
            if [[ -n "''${KITTY_LISTEN_ON:-}" ]]; then
              ${pkgs.kitty}/bin/kitty @ --to "$KITTY_LISTEN_ON" send-text --stdin
            else
              # Fallback: try default target (less secure; avoid if possible).
              ${pkgs.kitty}/bin/kitty @ send-text --stdin
            fi
          }

          # POSIX shell-quoting: wrap in single quotes and escape any embedded single quotes.
          # Result is safe for bash, zsh, dash, etc.
          sh_quote() {
            local s=$1
            # Replace each ' with '"'"'
            printf "'%s'" "''${s//\'/\'\"\'\"\'}"
          }

          # Minimal URI percent-decoder (for file:// URIs). Converts %XX and + to space.
          urldecode() {
            local s=''${1//+/ } out
            # Turn %XX into \xXX for printf %b. Non-hex sequences will cause printf to warn;
            # we guard by only converting valid %HH patterns.
            s="$(printf '%s' "$s" | sed -E 's/%([0-9a-fA-F]{2})/\\x\1/g')"
            printf '%b' "$s"
          }

          # Choose best image MIME type: prefer image/png if present, else first image/*
          pick_image_mime() {
            local types=$1
            local mime
            mime="$(printf '%s\n' "$types" | awk '/^image\/png([;]|$)/{print; exit}')"
            [[ -z "$mime" ]] && mime="$(printf '%s\n' "$types" | awk '/^image\//{print; exit}')"
            printf '%s' "$mime"
          }

          # Derive a sane lowercase extension from a MIME type. Fallback to "bin".
          ext_from_mime() {
            local mime=$1 main=''${mime%%/*} rest=''${mime#*/}
            local base=''${rest%%;*}
            base=''${base,,}
            case "$mime" in
              image/jpeg|image/jpg) printf 'jpg';;
              image/tiff)           printf 'tif';;
              image/svg+xml)        printf 'svg';;
              *)                    printf '%s' "''${base//[^a-z0-9]/}";;
            esac
            [[ -z "$base" ]] && printf 'bin'
          }

          # Create a unique path for saved image in TMPDIR (does not rely on non-portable mktemp suffix flags)
          unique_image_path() {
            local ext=$1
            local tdir=''${CLIP2PATH_TMPDIR:-''${TMPDIR:-/tmp}}
            [[ -d "$tdir" && -w "$tdir" ]] || die "temp dir not writable: $tdir"
            local tmp
            tmp="$(mktemp -p "$tdir" clip2path_XXXXXX)" || die "mktemp failed"
            local file="''${tmp}.''${ext}"
            mv "$tmp" "$file" || die "failed to reserve temp file"
            printf '%s' "$file"
          }

          # Read the clipboard types (Wayland)
          list_types_wayland() {
            wl-paste --list-types 2>/dev/null || true
          }

          # Read the clipboard types (X11)
          list_types_x11() {
            local tool=$(choose_x11_tool)
            case "$tool" in
              xclip) xclip -selection clipboard -t TARGETS -o 2>/dev/null || true;;
              xsel)  # xsel doesn't have direct TARGETS support, try common types
                     local types=()
                     xsel --clipboard --output >/dev/null 2>&1 && types+=("text/plain")
                     # Check for images by trying to get image data
                     if xclip -selection clipboard -t image/png -o >/dev/null 2>&1; then
                       types+=("image/png")
                     fi
                     printf '%s\n' "''${types[@]}";;
              *)     echo "";;
            esac
          }

          # Read the clipboard types (unified interface)
          list_types() {
            local display_server=$(detect_display_server)
            case "$display_server" in
              wayland) list_types_wayland;;
              x11)     list_types_x11;;
              *)       echo "";;
            esac
          }

          # Save image from Wayland clipboard
          save_image_wayland() {
            local mime=$1 file=$2
            wl-paste --type "$mime" >"$file"
          }

          # Save image from X11 clipboard  
          save_image_x11() {
            local mime=$1 file=$2
            local tool=$(choose_x11_tool)
            case "$tool" in
              xclip) xclip -selection clipboard -t "$mime" -o >"$file";;
              xsel)  # xsel doesn't support MIME types directly, try generic
                     xsel --clipboard --output >"$file";;
              *)     return 1;;
            esac
          }

          # Save image target to file and paste quoted path.
          save_image_and_paste_path() {
            local types=$1 mime ext file display_server
            mime="$(pick_image_mime "$types")"
            [[ -z "$mime" ]] && return 1
            ext="$(ext_from_mime "$mime")"
            [[ -z "$ext" ]] && ext="bin"
            file="$(unique_image_path "$ext")"
            debug "saving image as $file (mime=$mime)"

            display_server=$(detect_display_server)
            case "$display_server" in
              wayland) save_image_wayland "$mime" "$file";;
              x11)     save_image_x11 "$mime" "$file";;
              *)       return 1;;
            esac

            if [[ $? -ne 0 ]]; then
              rm -f -- "$file"
              return 1
            fi

            # Guard against empty images: verify file exists and has non-zero size
            # Empty images cause catastrophic API errors that require restarting Claude Code session
            if [[ ! -s "$file" ]]; then
              debug "image file is empty, refusing to paste: $file"
              rm -f -- "$file"
              die "clipboard image is empty (0 bytes)"
            fi

            sh_quote "$file" | kitty_send_text
          }

          # ----- preflight -------------------------------------------------------------

          have ${pkgs.kitty}/bin/kitty || die "missing dependency: kitty"

          # Check display server and required clipboard tools
          display_server=$(detect_display_server)
          case "$display_server" in
            wayland)
              have wl-paste || die "missing dependency: wl-clipboard (wl-paste) for Wayland"
              debug "detected Wayland environment"
              ;;
            x11)
              x11_tool=$(choose_x11_tool)
              [[ "$x11_tool" != "none" ]] || die "missing dependency: xclip or xsel for X11"
              debug "detected X11 environment using $x11_tool"
              ;;
            *)
              die "unsupported display server: neither WAYLAND_DISPLAY nor DISPLAY is set"
              ;;
          esac

          # Check if running within Claude Code CLI (disabled)
          # [[ "''${CLAUDECODE:-0}" == "1" ]] || die "clip2path: only works within Claude Code CLI terminal sessions"

          # If launched via Kitty mapping with --allow-remote-control, KITTY_LISTEN_ON will be set.
          if [[ -z "''${KITTY_LISTEN_ON:-}" ]]; then
            debug "KITTY_LISTEN_ON not set; falling back to default kitty @ (consider using --allow-remote-control)"
          fi

          # ----- main ------------------------------------------------------------------

          types="$(list_types)"
          debug "clipboard types: $(printf '%q' "$types")"

          # Hybrid approach: images → file paths, text → kitty paste
          if grep -Eq '^image/' <<<"$types"; then
            debug "found image in clipboard, saving to file"
            if save_image_and_paste_path "$types"; then
              exit 0
            fi
            debug "image save failed"
            die "failed to save image from clipboard"
          else
            debug "no image found, delegating to kitty for text paste"
            # Let kitty handle text with its safety features
            if [[ -n "''${KITTY_LISTEN_ON:-}" ]]; then
              ${pkgs.kitty}/bin/kitty @ --to "$KITTY_LISTEN_ON" action paste_from_clipboard
            else
              ${pkgs.kitty}/bin/kitty @ action paste_from_clipboard
            fi
          fi
        '';

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
