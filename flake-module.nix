{ kittyLib }:
{
  perSystem = { ... }: {
    imports = kittyLib.moduleImports;

    _module.args = {
      inherit (kittyLib) defaults render;
    };
  };
}
