{ config, pkgs, lib, ... }:

let
  # Определяем архитектуру
  isAarch64 = pkgs.stdenv.hostPlatform.isAarch64;

  # Выбираем имена переменных окружения в зависимости от архитектуры
  mutterEnvVar = if isAarch64 then "MUTTER_PATH_ARM" else "MUTTER_PATH";
  gnomeShellEnvVar = if isAarch64 then "GNOME_SHELL_PATH_ARM" else "GNOME_SHELL_PATH";
  jasonbourneEnvVar = if isAarch64 then "JASONBOURNE_PATH_ARM" else "JASONBOURNE_PATH";

  # Получаем пути из выбранных переменных (требует --impure)
  mutterStorePath = builtins.getEnv mutterEnvVar;
  gnomeShellStorePath = builtins.getEnv gnomeShellEnvVar;
  jasonbourneStorePath = builtins.getEnv jasonbourneEnvVar;

  mkProprietary = originalPkg: storePath: envVarName:
    # Check if path is empty to provide a helpful error message
    if storePath == "" then
      throw "Environment variable '${envVarName}' is empty. Ensure .env is loaded and --impure is used."
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
        # dontStrip = true;
        dontPatchELF = true;
        dontPatchShebangs = true;
        dontMoveLib64 = true;
        dontGlibCompileSchemas = true;
        dontWrapGApps = true;
      });

  proprietaryOverlay = final: prev: {
    mutter       = mkProprietary prev.mutter mutterStorePath mutterEnvVar;
    gnome-shell = mkProprietary prev.gnome-shell gnomeShellStorePath gnomeShellEnvVar;

    jasonbourne = if jasonbourneStorePath == "" then
      throw "${jasonbourneEnvVar} env var is empty."
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
      # dontStrip = true;
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
