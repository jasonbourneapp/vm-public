{ config, pkgs, lib, ... }:

let
  # Import paths from environment variables (requires --impure)
  # Эти переменные определены в файле .env и читаются через justfile
  mutterStorePath = builtins.getEnv "MUTTER_PATH";
  gnomeShellStorePath = builtins.getEnv "GNOME_SHELL_PATH";
  jasonbourneStorePath = builtins.getEnv "JASONBOURNE_PATH";

  mkProprietary = originalPkg: storePath:
    # Check if path is empty to provide a helpful error message
    if storePath == "" then
      throw "Environment variable for proprietary store path is empty. Ensure .env is loaded and --impure is used."
    else
      originalPkg.overrideAttrs (_: {
        src = builtins.storePath storePath;

        outputs = [ "out" ];
        separateDebugInfo = false;

        phases = [ "installPhase" ];
        installPhase = ''
          mkdir -p $out
          cp -r $src/* $out/
          chmod -R u+w $out
        '';

        dontFixup = true;
        dontStrip = true;
        dontPatchELF = true;
        dontPatchShebangs = true;
        dontMoveLib64 = true;
        dontGlibCompileSchemas = true;
        dontWrapGApps = true;
      });

  proprietaryOverlay = final: prev: {
    mutter       = mkProprietary prev.mutter mutterStorePath;
    gnome-shell = mkProprietary prev.gnome-shell gnomeShellStorePath;

    jasonbourne = if jasonbourneStorePath == "" then
      throw "JASONBOURNE_PATH env var is empty."
    else prev.stdenv.mkDerivation {
      pname = "jasonbourne";
      version = "3.0.1";
      src = builtins.storePath jasonbourneStorePath;

      phases = [ "installPhase" ];
      installPhase = ''
        mkdir -p $out
        cp -r $src/* $out/
        chmod -R u+w $out
      '';

      dontFixup = true;
      dontStrip = true;
      dontPatchELF = true;
      dontPatchShebangs = true;
      dontMoveLib64 = true;
      dontGlibCompileSchemas = true;
      dontWrapGApps = true;
    };
  };

in {
  nixpkgs.overlays = [ proprietaryOverlay ];
}
