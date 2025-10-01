{
  description = "Kitty extended keys as a pkg + devShell (no Home Manager needed)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs }:
  let
    mkFor = system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        # --- Customize your key sequences here ---
        bindings = {
          # examples, extend freely:
          "ctrl+i"        = "\\x1b[105;5u";
          "ctrl+h"        = "\\x1b[104;5u";
          "ctrl+j"        = "\\x1b[106;5u";
          "ctrl+m"        = "\\x1b[109;5u";

          "ctrl+shift+a"  = "\\x1b[65;5u";
          "ctrl+shift+d"  = "\\x1b[68;5u";
          "ctrl+shift+e"  = "\\x1b[69;5u";
          "ctrl+shift+g"  = "\\x1b[71;5u";
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
          "ctrl+shift+w"  = "\\x1b[87;5u";
          "ctrl+shift+x"  = "\\x1b[88;5u";
          "ctrl+shift+y"  = "\\x1b[89;5u";
          "ctrl+shift+z"  = "\\x1b[90;5u";

          "ctrl+1"        = "\\x1b[49;5u";
          "ctrl+2"        = "\\x1b[50;5u";
          "ctrl+3"        = "\\x1b[51;5u";
          "ctrl+4"        = "\\x1b[52;5u";
          "ctrl+5"        = "\\x1b[53;5u";
          "ctrl+6"        = "\\x1b[54;5u";
          "ctrl+7"        = "\\x1b[55;5u";
          "ctrl+8"        = "\\x1b[56;5u";
          "ctrl+9"        = "\\x1b[57;5u";

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
                --add-flags "--config ${extended-keys-conf}"
            '';
          });
      in
      {
        packages = {
          default = kitty-extended;
          extended-keys-conf = extended-keys-conf;
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
