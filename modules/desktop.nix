{ config, pkgs, lib, ... }:

{
  # === QEMU / SPICE ===
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  # === ГРАФИКА ===
  hardware.graphics = {
    enable = true;
    enable32Bit = pkgs.stdenv.hostPlatform.isx86_64;
  };

  services.xserver = {
    enable = true;
    videoDrivers = [ "modesetting" ];
  };

  # === GNOME & GDM ===
  services.displayManager.gdm = {
    enable = true;
    autoSuspend = false;
  };

  services.desktopManager.gnome.enable = true;

  services.displayManager.autoLogin = {
    enable = true;
    user = "user";
  };

  services.gnome.gnome-keyring.enable = true;

  services.gnome = {
    core-utilities.enable = false; # Отключить все утилиты GNOME
    games.enable = false;
    gnome-browser-connector.enable = false;
  };

  # === ЗВУК ===
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # === ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ ===
  environment = {
    sessionVariables = rec {
      GTK_THEME = "Adwaita:dark";
      # Эта переменная будет работать, если ваш бинарный Mutter был скомпилирован с ее поддержкой
      MUTTER_HIDE_WINDOWS_BY_TITLE = "jasonbourne_always_on_top";
    };
  };
}
